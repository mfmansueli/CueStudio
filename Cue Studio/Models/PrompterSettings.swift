//
//  PrompterSettings.swift
//  Cue Studio
//

import Foundation

/// How the prompter looks and scrolls. Shared by Selfie and Studio mode.
nonisolated struct PrompterSettings: Codable, Hashable, Sendable {
    static let speedRange: ClosedRange<Double> = 0.3...3
    static let sizeRange: ClosedRange<Double> = 16...56
    static let lineSpacingRange: ClosedRange<Double> = 1...2
    static let marginRange: ClosedRange<Double> = 8...64
    static let dimRange: ClosedRange<Double> = 0...0.9
    static let guideRange: ClosedRange<Double> = 0.1...0.7
    /// Studio mode is read from further away, so its text is bigger than the selfie panel's.
    static let studioScale: Double = 1.35

    var speed: Double = 1
    var font: PrompterFont = .lexend
    var size: Double = 28
    var lineSpacing: Double = 1.35
    var alignment: PrompterAlignment = .center
    var textColor: PrompterTextColor = .white
    var margin: Double = 24
    /// Darkening behind the text in Selfie mode.
    var dim: Double = 0.5
    var showsGuide: Bool = true
    /// Reading line position, as a fraction of the text area height.
    var guidePosition: Double = 0.3
    var isMirrored: Bool = false
    var scrollMode: ScrollMode = .steady
    var studioBackground: StudioBackground = .black
    var showsCues: Bool = true

    var speedLabel: String {
        speed.formatted(.number.precision(.fractionLength(1))) + "×"
    }
}
