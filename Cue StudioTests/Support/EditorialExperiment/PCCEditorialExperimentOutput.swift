//
//  PCCEditorialExperimentOutput.swift
//  Cue StudioTests
//

/// Native experiment evidence. Trace is recorded separately from model inputs so input measurements are not inflated by audit text.
nonisolated struct PCCEditorialExperimentOutput: Sendable {
    let text: String
    let prompts: [String]
    var trace: String?
}
