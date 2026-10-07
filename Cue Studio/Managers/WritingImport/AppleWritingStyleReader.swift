//
//  AppleWritingStyleReader.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// Reads the creator's writing with the model on the iPhone, and only that one: what they imported never goes to Private Cloud Compute. One short
/// request, given up on after `limit`, that stands aside when a script is being written (`isBusy`).
@MainActor
final class AppleWritingStyleReader: WritingStyleReading {
    /// Characters of each text the model reads, and how many texts.
    static let sampleCharacters = 400
    static let sampleCount = 4
    static var limit: Duration = .seconds(40)

    private let isBusy: () -> Bool
    private let isEnabled: () -> Bool

    /// - Parameters:
    ///   - isBusy: a script the creator is waiting for is being written.
    ///   - isEnabled: Settings › Privacy & AI data › On-device AI is on: with it off no AI feature runs, this one included.
    init(isBusy: @escaping () -> Bool = { false }, isEnabled: @escaping () -> Bool = { true }) {
        self.isBusy = isBusy
        self.isEnabled = isEnabled
    }

    func canRead(language: String?) -> Bool {
        guard isEnabled(), !isBusy(), case .available = SystemLanguageModel.default.availability else { return false }
        guard let language else { return true }
        return SystemLanguageModel.default.supportsLocale(Locale(identifier: language))
    }

    func read(_ samples: [String], language: String?) async -> StyleReading? {
        guard canRead(language: language), !samples.isEmpty else { return nil }
        let prompt = "Scripts:\n" + samples.prefix(Self.sampleCount).enumerated()
            .map { "\($0.offset + 1). \(String($0.element.prefix(Self.sampleCharacters)))" }.joined(separator: "\n")
        let started = ContinuousClock.now
        let work = Task { () -> StyleReading? in
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: "You read short video scripts that one creator wrote and describe the writer. Answer only with the listed choices."
            )
            do {
                return try await session.respond(to: prompt, generating: StyleReading.self).content
            } catch is CancellationError {
                return nil
            } catch {
                let seconds = Double((ContinuousClock.now - started).components.seconds)
                AIFailureReport.note(error, operation: "styleReading", route: nil, language: language, seconds: seconds, isFinal: true)
                return nil
            }
        }
        let watchdog = Task {
            try? await Task.sleep(for: Self.limit)
            work.cancel()
        }
        defer { watchdog.cancel() }
        return await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
    }
}
