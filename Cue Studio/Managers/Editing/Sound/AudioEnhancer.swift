//
//  AudioEnhancer.swift
//  Cue Studio
//

import AVFoundation
import AudioToolbox

/// Quick edit › Voice, rendered offline with AVAudioEngine on the device. Apple has no
/// noise-reduction API for files, so this is an equalizer-and-dynamics approximation, kept
/// conservative so a voice never sounds processed:
///
/// - **Version 1** (edits made before the levels): volume up to 150%, "Enhance voice" (less mud,
///   more presence, gentle compression) and "Reduce background noise" (low rumble cut and a soft
///   gate between words). Unchanged, so those edits sound as they did.
/// - **Version 2**: Enhance Voice and Reduce Noise each off, soft or strong, independent. Enhance
///   cuts mud, lifts presence and a touch of air, and evens the level; Reduce Noise cuts rumble
///   and a little hiss and lowers the room between words (an expander, not a gate, so word ends
///   stay). A peak limiter ends the chain and the result is kept under `AudioCeiling`.
/// - **Version 3**: the same, with Reduce Noise through Apple's voice isolation
///   (`AUSoundIsolation`, the system's own on-device model): Soft blends half of it, Strong all of
///   it; the expander then stays out. Where the unit isn't on the device or can't render offline,
///   it falls back to version 2's treatment.
nonisolated enum AudioEnhancer {
    enum RenderError: Error {
        case noBuffer
        case renderFailed
    }

    /// The take's sound treated as `processing` says, as a new file.
    static func process(_ source: URL, processing: VoiceProcessing) throws -> URL {
        if processing.version == 1 {
            return try process(source, volume: processing.volume, enhancesVoice: processing.enhancesVoice, reducesNoise: processing.reducesNoise)
        }
        if processing.version >= 3, processing.noise != .off, let isolation = soundIsolation(processing.noise) {
            do {
                let rendered = try render(source, through: [
                    isolation,
                    equalizer(volume: processing.volume, enhancement: processing.enhancement, noise: processing.noise),
                    dynamics(enhancement: processing.enhancement, noise: .off),
                    limiter(),
                ])
                return try AudioCeiling.keepingUnder(rendered)
            } catch {
                // Falls through to the equalizer and expander alone.
            }
        }
        let rendered = try render(source, through: [
            equalizer(volume: processing.volume, enhancement: processing.enhancement, noise: processing.noise),
            dynamics(enhancement: processing.enhancement, noise: processing.noise),
            limiter(),
        ])
        return try AudioCeiling.keepingUnder(rendered)
    }

    /// Version 1's treatment.
    static func process(_ source: URL, volume: Double, enhancesVoice: Bool, reducesNoise: Bool) throws -> URL {
        let equalizer = AVAudioUnitEQ(numberOfBands: 3)
        configure(equalizer, volume: volume, enhancesVoice: enhancesVoice, reducesNoise: reducesNoise)
        let dynamics = dynamicsProcessor()
        configure(dynamics, enhancesVoice: enhancesVoice, reducesNoise: reducesNoise)
        return try render(source, through: [equalizer, dynamics])
    }

    /// A whole mix through the peak limiter, then kept under the ceiling: the last step of an
    /// export that mixes more than the take's sound.
    static func limit(_ source: URL) throws -> URL {
        let limited = try render(source, through: [limiter()])
        return try AudioCeiling.keepingUnder(limited)
    }

    /// Gain in decibels for a volume factor: 1 is 0 dB, 1.5 about +3.5 dB, 0 silent.
    static func gain(forVolume volume: Double) -> Float {
        guard volume > 0.001 else { return -96 }
        return Float(20 * log10(volume))
    }

    // MARK: - Rendering

    /// `source` played through `units` in order, as fast as the device can.
    private static func render(_ source: URL, through units: [AVAudioNode]) throws -> URL {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        var previous: AVAudioNode = player
        for unit in units {
            engine.attach(unit)
            try engine.connectNode(previous, to: unit, format: format)
            previous = unit
        }
        try engine.connectNode(previous, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()
        player.scheduleFile(input, at: nil)
        try player.playAudio()

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

    private static func effect(_ subType: OSType) -> AVAudioUnitEffect {
        AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: subType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0
        ))
    }

    private static func dynamicsProcessor() -> AVAudioUnitEffect {
        effect(kAudioUnitSubType_DynamicsProcessor)
    }

    /// Apple's voice isolation, mixed in by `strength`; nil when this device doesn't have it.
    private static func soundIsolation(_ strength: AudioStrength) -> AVAudioUnitEffect? {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_AUSoundIsolation,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0
        )
        guard AudioComponentFindNext(nil, &description) != nil else { return nil }
        let isolation = effect(kAudioUnitSubType_AUSoundIsolation)
        let mix: Float = strength == .strong ? 100 : 50
        isolation.withAudioUnit { unit in
            AudioUnitSetParameter(unit, kAUSoundIsolationParam_WetDryMixPercent, kAudioUnitScope_Global, 0, mix, 0)
            AudioUnitSetParameter(
                unit, kAUSoundIsolationParam_SoundToIsolate, kAudioUnitScope_Global, 0,
                Float(kAUSoundIsolationSoundType_HighQualityVoice), 0
            )
        }
        return isolation
    }

    /// Catches the peaks quickly and lets go smoothly.
    private static func limiter() -> AVAudioUnitEffect {
        let limiter = effect(kAudioUnitSubType_PeakLimiter)
        limiter.withAudioUnit { unit in
            AudioUnitSetParameter(unit, kLimiterParam_AttackTime, kAudioUnitScope_Global, 0, 0.005, 0)
            AudioUnitSetParameter(unit, kLimiterParam_DecayTime, kAudioUnitScope_Global, 0, 0.05, 0)
            AudioUnitSetParameter(unit, kLimiterParam_PreGain, kAudioUnitScope_Global, 0, 0, 0)
        }
        return limiter
    }

    // MARK: - Version 2

    /// Rumble, mud, presence, air and hiss, each only when its setting asks for it.
    private static func equalizer(volume: Double, enhancement: AudioStrength, noise: AudioStrength) -> AVAudioUnitEQ {
        let equalizer = AVAudioUnitEQ(numberOfBands: 5)
        equalizer.globalGain = gain(forVolume: volume)
        let strong = enhancement == .strong
        let rumble = equalizer.bands[0]
        rumble.filterType = .highPass
        rumble.frequency = switch noise {
        case .off: 70
        case .soft: 90
        case .strong: 110
        }
        rumble.bypass = enhancement == .off && noise == .off
        let mud = equalizer.bands[1]
        mud.filterType = .parametric
        mud.frequency = 250
        mud.bandwidth = 1.2
        mud.gain = strong ? -3.5 : -2
        mud.bypass = enhancement == .off
        let presence = equalizer.bands[2]
        presence.filterType = .parametric
        presence.frequency = 3500
        presence.bandwidth = 1.4
        presence.gain = strong ? 3.5 : 2
        presence.bypass = enhancement == .off
        let air = equalizer.bands[3]
        air.filterType = .highShelf
        air.frequency = 10_000
        air.gain = strong ? 2 : 1
        air.bypass = enhancement == .off
        let hiss = equalizer.bands[4]
        hiss.filterType = .highShelf
        hiss.frequency = 8000
        hiss.gain = noise == .strong ? -4 : -2
        hiss.bypass = noise == .off
        return equalizer
    }

    /// Compression evens out the voice; expansion lowers the room between words.
    private static func dynamics(enhancement: AudioStrength, noise: AudioStrength) -> AVAudioUnitEffect {
        let dynamics = dynamicsProcessor()
        let threshold: Float, headroom: Float, makeUp: Float
        switch enhancement {
        case .off: (threshold, headroom, makeUp) = (0, 20, 0)
        case .soft: (threshold, headroom, makeUp) = (-20, 10, 2)
        case .strong: (threshold, headroom, makeUp) = (-24, 6, 4)
        }
        let ratio: Float, floor: Float
        switch noise {
        case .off: (ratio, floor) = (1, -100)
        case .soft: (ratio, floor) = (2, -52)
        case .strong: (ratio, floor) = (3.5, -46)
        }
        dynamics.withAudioUnit { unit in
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, threshold, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, headroom, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, ratio, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_ExpansionThreshold, kAudioUnitScope_Global, 0, floor, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, makeUp, 0)
        }
        dynamics.bypass = enhancement == .off && noise == .off
        return dynamics
    }

    // MARK: - Version 1

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
        dynamics.withAudioUnit { unit in
            // Compression evens out the voice; expansion quiets what's between words.
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, enhancesVoice ? -22 : 0, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, enhancesVoice ? 8 : 20, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_ExpansionRatio, kAudioUnitScope_Global, 0, reducesNoise ? 3 : 1, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_ExpansionThreshold, kAudioUnitScope_Global, 0, reducesNoise ? -48 : -100, 0)
            AudioUnitSetParameter(unit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, enhancesVoice ? 3 : 0, 0)
        }
        dynamics.bypass = !(enhancesVoice || reducesNoise)
    }
}
