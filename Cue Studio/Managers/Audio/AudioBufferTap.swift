//
//  AudioBufferTap.swift
//  Cue Studio
//

import AVFoundation
import Synchronization

/// Live microphone audio, from the audio thread to whoever listens (Voice follow's speech
/// recognition), plus the latest level. Serves as the audio engine's tap in Studio mode and as the
/// capture session's audio data delegate in Selfie mode.
nonisolated final class AudioBufferTap: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, Sendable {
    private struct State {
        var handler: (@Sendable (AVAudioPCMBuffer) -> Void)?
        var level: Float?
    }

    private let state = Mutex(State())

    /// Average power of the latest buffer in dBFS. Nil before any audio.
    var level: Float? { state.withLock { $0.level } }

    /// Receives every buffer on the audio thread. Nil stops forwarding.
    func setHandler(_ handler: (@Sendable (AVAudioPCMBuffer) -> Void)?) {
        state.withLock { $0.handler = handler }
    }

    func resetLevel() {
        state.withLock { $0.level = nil }
    }

    /// For `AVAudioNode.installTap`, which calls it on the audio thread. Built here, outside the
    /// main actor, so the closure isn't main-actor isolated.
    var tapBlock: AVAudioNodeTapBlock {
        { [self] buffer, _ in receive(buffer) }
    }

    func receive(_ buffer: AVAudioPCMBuffer) {
        let level = Self.averagePower(of: buffer)
        let handler = state.withLock { state in
            state.level = level
            return state.handler
        }
        handler?(buffer)
    }

    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // The camera always delivers audio; only convert it while someone listens.
        guard state.withLock({ $0.handler != nil }), let buffer = Self.pcmBuffer(from: sampleBuffer) else { return }
        receive(buffer)
    }

    // MARK: - Conversion

    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = sampleBuffer.formatDescription,
              let format = AVAudioFormat(formatDescription: description) else { return nil }
        let frames = AVAudioFrameCount(sampleBuffer.numSamples)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList
        )
        return status == noErr ? buffer : nil
    }

    private static func averagePower(of buffer: AVAudioPCMBuffer) -> Float? {
        let frames = Int(buffer.frameLength)
        let stride = buffer.stride
        guard frames > 0 else { return nil }
        var sum: Float = 0
        if let samples = buffer.floatChannelData?[0] {
            for frame in 0..<frames {
                let sample = samples[frame * stride]
                sum += sample * sample
            }
        } else if let samples = buffer.int16ChannelData?[0] {
            for frame in 0..<frames {
                let sample = Float(samples[frame * stride]) / Float(Int16.max)
                sum += sample * sample
            }
        } else {
            return nil
        }
        let rms = (sum / Float(frames)).squareRoot()
        return rms > 0 ? 20 * log10(rms) : -160
    }
}
