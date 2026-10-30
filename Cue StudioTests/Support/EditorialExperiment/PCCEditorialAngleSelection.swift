//
//  PCCEditorialAngleSelection.swift
//  Cue StudioTests
//

import FoundationModels

@Generable
nonisolated struct PCCEditorialAngleSelection {
    @Guide(description: "Three genuinely different explanations or distinctions, not three analogies or wordings of the same claim.", .minimumCount(3), .maximumCount(3))
    var candidates: [PCCEditorialAngle]
    @Guide(description: "Choose the zero-based candidate with the clearest explanatory mechanism and most demonstrable contrast, faithful to the request.", .range(0...2))
    var selectedIndex: Int
    @Guide(description: "One brief editorial justification for this choice based on substance rather than its hook or wording. Never spoken in the script.")
    var selectionReason: String
}
