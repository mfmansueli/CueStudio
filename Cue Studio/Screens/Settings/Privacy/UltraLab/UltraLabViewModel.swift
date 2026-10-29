//
//  UltraLabViewModel.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// AI Scripts Ultra's lab (Settings › Privacy & AI data): one idea written by the same `UltraScriptService` the Scripts screen uses, under a chosen
/// length condition, with the draft, the polish and the editor's changes side by side. A new run clears the last one first (a failed run never
/// shows the previous script), Stop cancels before the next call, and a script is saved once, with its language, format, Ultra's provenance and
/// the fact-check reminder.
@MainActor
@Observable
final class UltraLabViewModel {
    var prompt = ""
    var length: UltraLabLength = .free
    /// The lab compares the passes by hand: the claim check on its own (the step the quality comparison measures) or folded into the polish.
    var flow = UltraFlow.checked

    private(set) var run: UltraRun?
    /// What went wrong, in the creator's words; never the provider's message.
    private(set) var failure: String?
    /// A draft whose polish failed: shown apart, marked as unfinished, never saved as the script.
    private(set) var unfinishedDraft: String?
    private(set) var meter: WritingProgressMeter?
    private(set) var isWorking = false
    private(set) var savedID: UUID?

    let ultra: UltraScriptService
    @ObservationIgnored private let starter: ScriptStarter
    @ObservationIgnored private let library: ScriptLibraryService
    @ObservationIgnored private let languages: LanguageService
    /// The request the shown run was written from: what it is saved with.
    @ObservationIgnored private var runRequest: ScriptRequest?
    @ObservationIgnored private var task: Task<Void, Never>?

    init(ultra: UltraScriptService, starter: ScriptStarter, library: ScriptLibraryService, languages: LanguageService) {
        self.ultra = ultra
        self.starter = starter
        self.library = library
        self.languages = languages
    }

    private var trimmedPrompt: String { prompt.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canGenerate: Bool {
        ultra.isReady && !isWorking && !trimmedPrompt.isEmpty && ultra.budget.allows(flow.calls)
    }

    /// The idea as the Scripts screen would send it (the dock's platform, no format), for Ultra.
    var request: ScriptRequest {
        var request = starter.factory.request(idea: trimmedPrompt.isEmpty ? prompt : trimmedPrompt, platform: starter.platform, format: nil)
        request.engine = .ultra
        return request
    }

    /// What the two calls carry under the chosen length.
    var payload: UltraPayload { UltraPayload(request, length: length.length) }

    /// The script's estimated speaking time at Cue's natural pace: an estimate from the word count, not a person reading it.
    var estimatedSeconds: Int? {
        run.map { Int(ReadTime.seconds(for: $0.script.text).rounded()) }
    }

    func generate() {
        guard canGenerate else { return }
        let request = request
        let length = length.length
        let meter = WritingProgressMeter(for: request)
        run = nil
        failure = nil
        unfinishedDraft = nil
        savedID = nil
        runRequest = request
        self.meter = meter
        isWorking = true
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                isWorking = false
                self.meter = nil
                task = nil
            }
            do {
                run = try await ultra.run(request, length: length, flow: flow, reporting: meter)
            } catch is CancellationError {
                failure = "Stopped · Nothing more was sent"
            } catch let error as UltraError {
                failure = error.localizedDescription
                if case .reviewFailed(_, let draft) = error { unfinishedDraft = draft }
            } catch {
                failure = ScriptDetailViewModel.failureMessage(for: error)
            }
        }
    }

    /// Stops before the next call goes out (one already out finishes on Google's side, but nothing of it is used).
    func stop() {
        task?.cancel()
    }

    /// Saves the polished script once (a second tap opens the same one) and returns it.
    @discardableResult
    func save() -> UUID? {
        if let savedID { return savedID }
        guard let run, let request = runRequest, !isWorking else { return nil }
        let script = library.create(
            title: run.script.title, text: run.script.text, platform: request.platform, type: request.type, factCheck: true,
            language: request.language ?? languages.scriptLanguage, isFinished: false
        )
        library.update(script.id) { $0.draftedBy = .ultra }
        savedID = script.id
        return script.id
    }
}
#endif
