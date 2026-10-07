//
//  GatedScriptWriter.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A writer that takes its time (until `release()`), so tests can ask again, cancel or fail while a
/// request is running. Cancelling the request ends it with `CancellationError`, like the real model.
@MainActor
final class GatedScriptWriter: ScriptWriting {
    var isEnabled = true
    var availability = AIAvailability(onDevice: true, privateCloud: false, reason: nil)
    /// When set, the request fails with it once released.
    var failure: Error?
    private(set) var started = 0
    private(set) var finished = 0
    private(set) var cancelled = 0
    private var gate: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func generate(_ request: ScriptRequest) async throws -> GeneratedScript {
        started += 1
        if !isReleased {
            await withTaskCancellationHandler {
                await withCheckedContinuation { gate = $0 }
            } onCancel: {
                Task { @MainActor in self.open() }
            }
        }
        if Task.isCancelled {
            cancelled += 1
            throw CancellationError()
        }
        finished += 1
        if let failure { throw failure }
        return GeneratedScript(title: "Gated", text: "Hello there.\n\nBody.", usedLanguageModel: true)
    }

    /// Lets the waiting request go on.
    func release() {
        isReleased = true
        open()
    }

    private func open() {
        gate?.resume()
        gate = nil
    }

    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String { text }
    func hooks(for text: String, context: RewriteContext) async throws -> [String] { [] }
    func themeIdeas(for niches: [Niche], language: CueLanguage?, voice: CreatorVoice?) async throws -> [ThemeIdea] { [] }
}
