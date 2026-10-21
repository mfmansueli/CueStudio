//
//  ResponseStructure.swift
//  Cue Studio
//

import Foundation

/// The structure the answer is written in (`@Generable`), which the framework puts in the request.
nonisolated enum ResponseStructure: Sendable {
    case script, ideas, text
}
