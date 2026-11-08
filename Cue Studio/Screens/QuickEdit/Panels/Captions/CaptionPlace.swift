//
//  CaptionPlace.swift
//  Cue Studio
//

import Foundation

/// Where picked caption lines go (Captions › Select › Place): with every caption, or in their own place at the top, the middle
/// or the bottom (`CaptionLineStyle.y`).
enum CaptionPlace: Hashable, Identifiable, CaseIterable {
    case withAll
    case own(CaptionPosition)

    static var allCases: [CaptionPlace] { [.withAll] + CaptionPosition.allCases.map(CaptionPlace.own) }

    var id: String {
        switch self {
        case .withAll: "all"
        case .own(let position): position.rawValue
        }
    }

    var label: String {
        switch self {
        case .withAll: String(localized: "With all captions")
        case .own(let position): position.label
        }
    }
}
