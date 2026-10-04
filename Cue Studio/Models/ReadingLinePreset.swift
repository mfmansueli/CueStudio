//
//  ReadingLinePreset.swift
//  Cue Studio
//

import Foundation

/// Where the reading line sits, in three places (Settings › Prompter): right under the camera lens, in the upper
/// third of the screen, or in the middle. A line moved by hand to another spot matches none.
nonisolated enum ReadingLinePreset: Int, CaseIterable, Identifiable, Sendable {
    case nearCamera, upperThird, middle

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .nearCamera: String(localized: "Near the camera")
        case .upperThird: String(localized: "Upper third")
        case .middle: String(localized: "Middle")
        }
    }

    /// Points below the front camera. Near the camera is Cue's recommended spot.
    var placement: ReadingLinePlacement {
        switch self {
        case .nearCamera: .recommended
        case .upperThird: .offset(200)
        case .middle: .offset(300)
        }
    }

    /// The preset a placement is (a placement within 12 pt of one counts as it).
    init?(_ placement: ReadingLinePlacement) {
        guard let match = Self.allCases.first(where: { preset in
            switch (preset.placement, placement) {
            case (.recommended, .recommended): true
            case (.offset(let lhs), .offset(let rhs)): abs(lhs - rhs) <= 12
            default: false
            }
        }) else { return nil }
        self = match
    }
}
