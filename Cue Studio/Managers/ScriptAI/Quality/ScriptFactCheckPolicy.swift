import Foundation

/// A model's own claim that it stated no facts is not a factual verification.
/// Free PCC drafts stay marked for creator review; the existing banner is informational.
nonisolated enum ScriptFactCheckPolicy {
    static func needsReview(for request: ScriptRequest, on route: AIModelRoute, statesFacts: Bool) -> Bool {
        route == .privateCloud || request.isFactualTopic || statesFacts
    }
}
