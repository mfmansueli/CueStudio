import FoundationModels

/// Spoken events and reactions, rather than a tutorial's explanation and practical advice.
@Generable
nonisolated struct PCCSceneBeat {
    @Guide(description: "A full spoken moment in the requested grammatical narrator: a concrete action, obstacle or exchange the viewer can picture. Show the event unfolding with specific details instead of summarizing the entire story in one sentence. Invent details only when fiction is explicitly requested; otherwise stay within supplied events.")
    var moment: String
    @Guide(description: "What the narrator or character does or says in response, moving the scene forward. Give the response room to unfold through connected spoken sentences where useful. Escalate or resolve the actual obstacle. No filming advice, explanation of why this is tense, generic lesson or unsolicited CTA. Empty only when the moment already contains the complete response.")
    var response: String
}
