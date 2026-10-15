//
//  PromptMeasuring.swift
//  Cue Studio
//

import Foundation

/// What a request costs a model's window, counted by the model's own tokenizer: the instructions, the prompt and the structure of the answer
/// (`ContextBudget`). Behind a protocol so the fitting is tested without a model, and so another model (Private Cloud Compute) can bring its own count
/// when the app offers it; nil wherever a count can't be had.
nonisolated protocol PromptMeasuring: Sendable {
    /// The tokens the model's window holds in all, for the request and its answer.
    var window: Int? { get }
    /// The tokens of a request: its instructions, its prompt and, for guided generation, the answer's structure.
    func tokens(instructions: String, prompt: String, structure: ResponseStructure) async -> Int?
}

/// The structure the answer is written in (`@Generable`), which the framework puts in the request.
nonisolated enum ResponseStructure: Sendable {
    case script, ideas, text
}
