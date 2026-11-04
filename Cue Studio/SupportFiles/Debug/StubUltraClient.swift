//
//  StubUltraClient.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Ultra for UI tests (`-uiTestUltra`): no Firebase, no network, a predictable draft and polish. `-uiTestUltraReviewFails` makes the polish fail
/// (the draft is never passed off as the script) and `-uiTestUltraSlow` holds each call for two seconds (Stop and Cancel between the calls).
/// `-uiTestUltraPaced` paces each call as Gemini's usually go, a think and then its words in steps (Ultra AI's scene round the star, filmed:
/// `UltraWaitScene`); `-uiTestUltraPacedLong` thinks 20 s more on the polish (a long chapter's comet). Each answer reports the usage the iPhone
/// measured for its step, so the lab's cost reads as a real script's would.
@MainActor
final class StubUltraClient: UltraModelClient {
    /// How a paced call goes: how long it thinks, then its words in `steps`, a quarter of a second apart.
    enum Pace {
        case usual, long

        func thinking(_ stage: UltraStageRequest.Stage) -> Duration {
            if stage == .review, self == .long { return .seconds(22) }
            return stage == .check ? .seconds(3) : .seconds(2.5)
        }
    }

    let reviewFails: Bool
    let delay: Duration
    let pace: Pace?
    /// `-uiTestUltraLong`: the polish comes back past a vertical network's ideal (about 1:52), short of the line where Ultra fits it by itself.
    let writesLong: Bool
    /// What was asked, in order: what the tests read back.
    private(set) var requests: [UltraStageRequest] = []

    init(reviewFails: Bool = false, delay: Duration = .zero, pace: Pace? = nil, writesLong: Bool = false) {
        self.reviewFails = reviewFails
        self.delay = delay
        self.pace = pace
        self.writesLong = writesLong
    }

    /// The words a paced call reports in steps: the draft as long as a vertical script (220 words), the others the draft's.
    static let pacedDraftWords = 220

    static let draftText = "Ultra draft paragraph one, with a reason and an example.\n\nUltra draft paragraph two, with the consequence."
    static let scriptText = "Ultra polished opening, with a reason and an example.\n\nUltra polished closing, with the consequence that follows."
    static let fittedText = "Ultra fitted script, with its reason and the consequence."
    static let title = "Ultra stub script"
    /// 400 words: past TikTok's 2:30 at the natural pace, which makes Ultra fit it by itself (`UltraLength.overflowWords`); with
    /// `writesLong` that fit fails, so the page has a script past the ideal. Each paragraph is numbered: the same sentence twice is collapsed
    /// into one (`ScriptPromptBuilder.collapsingRepeatedSentences`).
    static let longScriptText = ([scriptText] + (1...32).map { "Ultra long paragraph \($0), with one more reason and one more example." })
        .joined(separator: "\n\n")

    func generate(_ request: UltraStageRequest, progress: @escaping @MainActor (Int) -> Void) async throws -> UltraModelReply {
        requests.append(request)
        if delay > .zero { try await Task.sleep(for: delay) }
        if let pace {
            try await Task.sleep(for: pace.thinking(request.stage))
            let words = request.stage == .draft ? Self.pacedDraftWords : ReadTime.wordCount(in: Self.draftText)
            let steps = 20
            for step in 1...steps {
                try await Task.sleep(for: .milliseconds(250))
                progress(words * step / steps)
            }
        }
        switch request.stage {
        case .draft:
            progress(ReadTime.wordCount(in: Self.draftText))
            return Self.metered(Self.draftText, request.stage)
        case .check:
            let reply = ["script": Self.draftText, "corrections": [String]()] as [String: Any]
            let data = try JSONSerialization.data(withJSONObject: reply)
            return Self.metered(String(bytes: data, encoding: .utf8) ?? "", request.stage)
        case .fit:
            if writesLong { throw UltraClientError(failure: .provider) }
            let data = try JSONSerialization.data(withJSONObject: ["script": Self.fittedText])
            return Self.metered(String(bytes: data, encoding: .utf8) ?? "", request.stage)
        case .ideas:
            return Self.metered(#"{"ideas":[]}"#, request.stage)
        case .review:
            if reviewFails { throw UltraClientError(failure: .provider) }
            let script = writesLong ? Self.longScriptText : Self.scriptText
            let reply = ["title": Self.title, "script": script, "changes": ["Tightened the opening."]] as [String: Any]
            let data = try JSONSerialization.data(withJSONObject: reply)
            return Self.metered(String(bytes: data, encoding: .utf8) ?? "", request.stage)
        }
    }

    /// The answer with its step's usage as the iPhone measured it (means of the 15 three-step scripts of 29/10/2026, which add up to about
    /// USD 0.076; the fit's estimated).
    private static func metered(_ text: String, _ stage: UltraStageRequest.Stage) -> UltraModelReply {
        let usage: (prompt: Int, output: Int, thinking: Int) = switch stage {
        case .draft: (1_000, 650, 1_600)
        case .check: (1_400, 500, 2_500)
        case .review: (1_465, 489, 2_053)
        case .fit: (1_300, 300, 2_000)
        case .ideas: (900, 9_000, 3_000)
        }
        return UltraModelReply(
            text: text, finishedNormally: true, promptTokens: usage.prompt, outputTokens: usage.output, thinkingTokens: usage.thinking
        )
    }
}
#endif
