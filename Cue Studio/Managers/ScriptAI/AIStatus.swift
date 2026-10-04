//
//  AIStatus.swift
//  Cue Studio
//

import Foundation

/// Whether Apple Intelligence can write on this iPhone, for screens that must not offer what it can't do (the paywall
/// never lists AI as a benefit on a device or in a language that can't run it).
@MainActor
@Observable
final class AIStatus {
    @ObservationIgnored private let writer: ScriptWriting

    init(writer: ScriptWriting) {
        self.writer = writer
    }

    var isAvailable: Bool { writer.isLanguageModelAvailable }
}
