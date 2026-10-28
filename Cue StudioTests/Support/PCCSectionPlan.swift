import FoundationModels

/// Evaluation-only outline for the owner's three-adjustment TikTok case, not a production format classifier.
@Generable
nonisolated struct PCCSectionPlan {
    @Guide(description: "A short video title in the creator's language.")
    var title: String
    @Guide(description: "Three distinct adjustments requested by the creator. Each entry names the action and an observable check; no invented personal experience.", .minimumCount(3), .maximumCount(3))
    var sections: [String]
}
