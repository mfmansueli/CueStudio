//
//  IdeaIngredientKind.swift
//  Cue Studio
//

import Foundation

/// The four kinds of concrete subject an idea is made around (`IdeaIngredients`), each for the angles it suits: a belief for a myth or a fact, a
/// mistake for a mistake or a lesson, a moment of everyday life for a story or an opinion, a thing for a list or a comparison. They are asked for
/// apart, and said without their kind's word, so a subject never brings its label into the idea: mixed in one list, "erro de cozinhar macarrão sem
/// sal" went into a comparison and came out "Comparação entre receitas de erro de cozinhar macarrão sem sal" (`IdeaLanguageDeviceTests`, 03/11/2026).
nonisolated enum IdeaIngredientKind: String, Codable, CaseIterable, Sendable {
    case belief, mistake, moment, thing

    init(angle: IdeaAngle) {
        switch angle {
        case .myth, .fact: self = .belief
        case .mistake, .lesson, .beginner: self = .mistake
        case .story, .dayInLife, .opinion, .question, .prediction, .challenge: self = .moment
        case .list, .tool, .comparison, .beforeAfter, .tutorial: self = .thing
        }
    }
}
