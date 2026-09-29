//
//  TextOverlay.swift
//  Cue Studio
//

import Foundation

/// A text laid over the edited video (a title, a hook, a callout…). Pinned to the recording like
/// captions: it shows while the part of the take it was placed on plays, so cutting or speeding
/// up something before it never moves it off what is being said. Rendered by the same code in the
/// preview and the export (`TextOverlayRenderer`).
nonisolated struct TextOverlay: Codable, Hashable, Identifiable, Sendable {
    static let sizeRange: ClosedRange<Double> = 12...72
    /// Shortest a text can stay on screen.
    static let minimumDuration: TimeInterval = 0.3

    var id = UUID()
    var text: String
    var role: TextOverlayRole
    var font: TextOverlayFont = .classic
    var weight: TextOverlayWeight = .bold
    /// Points on a 402-point-wide frame; scaled to the real frame when drawn.
    var size: Double
    var isUppercase = false
    var alignment: TextOverlayAlignment = .center
    var color: OverlayColor = .white
    var background: TextOverlayBackground = .none
    var backgroundColor: OverlayColor = .black
    var hasShadow = true
    var hasOutline = false
    /// The center of the text on the frame.
    var center: OverlayPoint
    /// Seconds of the recording it is pinned to.
    var span: TimeSpan

    /// A new text for `role` in `style`, shown over `span` of the recording.
    init(role: TextOverlayRole, style: CreatorStyle, span: TimeSpan) {
        text = role.placeholder
        self.role = role
        size = role.baseSize
        center = OverlayPoint(x: 0.5, y: role.defaultY)
        self.span = span
        style.apply(to: &self)
    }

    /// What is drawn: the text, in capitals when the style asks for them.
    var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return isUppercase ? trimmed.uppercased() : trimmed
    }

    /// Nothing to draw.
    var isEmpty: Bool { displayText.isEmpty }
}
