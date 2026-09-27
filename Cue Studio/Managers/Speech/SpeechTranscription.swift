//
//  SpeechTranscription.swift
//  Cue Studio
//

import AVFAudio

/// A running recognition. Microphone audio goes in through `audio` (called on the audio thread);
/// `transcripts` yields the text heard so far, newest words last, every time it changes.
nonisolated struct SpeechTranscription: Sendable {
    let audio: @Sendable (AVAudioPCMBuffer) -> Void
    let transcripts: AsyncStream<String>
}
