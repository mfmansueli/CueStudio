//
//  AudioEnhancer.swift
//  Cue Studio
//

import AVFoundation
import AudioToolbox

/// Quick edit › Audio, rendered offline with AVAudioEngine: volume up to 150%, "Enhance voice"
/// (less mud, more presence, gentle compression) and "Reduce background noise" (low rumble cut and
/// a soft gate between words). Apple has no noise-reduction API for files, so this is an
/// equalizer-and-dynamics approximation.
nonisolated enum AudioEnhancer {
    enum RenderError: Error {
        case noBuffer
        case renderFailed
    }

    static func process(_ source: URL, volume: Double, enhancesVoice: Bool, reducesNoise: Bool) throws -> URL {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let equalizer = AVAudioUnitEQ(numberOfBands: 3)
        configure(equalizer, volume: volume, enhancesVoice: enhancesVoice, reducesNoise: reducesNoise)
        let dynamics = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0
        ))
        configure(dynamics, enhancesVoice: enhancesVoice, reducesNoise: reducesNoise)

        engine.attach(player)
        engine.attach(equalizer)
        engine.attach(dynamics)
        engine.connect(player, to: equalizer, format: format)
        engine.connect(equalizer, to: dynamics, format: format)
        engine.connect(dynamics, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()
        player.scheduleFile(input, at: nil)
        player.play()

        let outputURL = URL.temporaryDirectory.appending(path: "Cue-mix-\(UUID().uuidString.prefix(8)).caf")
        let output = try AVAudioFile(forWriting: outputURL, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            throw RenderError.noBuffer
        }
        while engine.manualRenderingSampleTime < input.length {
            let remaining = AVAudioFrameCount(input.length - engine.manualRenderingSampleTime)
            let status = try engine.renderOffline(min(buffer.frameCapacity, remaining), to: buffer)
            switch status {
            case .success: try output.write(from: buffer)
            case .insufficientDataFromInputNode, .cannotDoInCurrentContext: continue
            case .error: throw RenderError.renderFailed
            @unknown default: continue
            }
        }
        player.stop()
        engine.stop()
        return outputURL
    }

    /// Gain in decibels for a volume factor: 1 is 0 dB, 1.5 about +3.5 dB, 0 silent.
    static func gain(forVolume volume: Double) -> Float {
        guard volume > 0.001 else { return -96 }
        return Float(20 * log10(volume))
    }

    private static func configure(_ equalizer: AVAudioUnitEQ, volume: Double, enhancesVoice: Bool, reducesNoise: Bool) {
        equalizer.globalGain = gain(forVolume: volume)
        let rumble = equalizer.bands[0]
        rumble.filterType = .highPass
        rumble.frequency = reducesNoise ? 110 : 60
        rumble.bypass = !(reducesNoise || enhancesVoice)
        let mud = equalizer.bands[1]
        mud.filterType = .parametric
        mud.frequency = 250
        mud.bandwidth = 1.2
        mud.gain = -2.5
        mud.bypass = !enhancesVoice
        let presence = equalizer.bands[2]
        presence.filterType = .parametric
        presence.frequency = 3200
        presence.bandwidth = 1.4
        presence.gain = 3
        presence.bypass = !enhancesVoice
    }

    private static func configure(_ dynamics: AVAudioUnitEffect, enhancesVoice: Bool, reducesNoise: Bool) {
        let unit = dynamics.audioUnit
        // Compression evens out the voice; expansion quiets what's between words.
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, enhancesVoice ? -22 : 0, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, enhancesVoice ? 8 : 20, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, reducesNoise ? 3 : 1, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_ExpansionThreshold, kAudioUnitScope_Global, 0, reducesNoise ? -48 : -100, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, enhancesVoice ? 3 : 0, 0)
        dynamics.bypass = !(enhancesVoice || reducesNoise)
    }
}
