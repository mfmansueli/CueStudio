//
//  MonoFont.swift
//  Cue Studio
//

import SwiftUI

extension View {
    /// Cue's monospaced face for small capitals, labels and readouts, in a language whose letters it has (Latin, Greek,
    /// Cyrillic); in any other (Arabic, Hindi, Thai, Japanese…) the system face with even digits, so the words are never drawn
    /// in a stretched stand-in for letters the face doesn't have.
    func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(MonoFont(size: .fixed(size), weight: weight))
    }

    /// The same at a text style's size, growing with the text size.
    func monoFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        modifier(MonoFont(size: .style(style), weight: weight))
    }

    /// HUD signals (counters, time, status lines): small, monospaced where the language allows it, growing with the text size.
    func hudFont() -> some View {
        monoFont(.caption, weight: .semibold)
    }
}

extension Font {
    /// `monoFont` for words drawn where a view modifier doesn't reach (a Canvas): the face for `locale`.
    static func mono(size: CGFloat, weight: Font.Weight = .regular, locale: Locale) -> Font {
        let design: Font.Design = TextShaping.hasMonospacedLetters(in: locale.language) ? .monospaced : .default
        return .system(size: size, weight: weight, design: design).monospacedDigit()
    }
}

extension Text {
    /// `interfaceTracking` for words drawn where a view modifier doesn't reach (a Canvas): none where `locale`'s letters join or
    /// stack.
    func interfaceTracking(_ value: CGFloat, locale: Locale) -> Text {
        tracking(TextShaping.allowsLetterSpacing(in: locale.language) ? value : 0)
    }
}

/// `monoFont`.
private struct MonoFont: ViewModifier {
    enum Size {
        case fixed(CGFloat)
        case style(Font.TextStyle)
    }

    let size: Size
    let weight: Font.Weight
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        let design: Font.Design = TextShaping.hasMonospacedLetters(in: locale.language) ? .monospaced : .default
        switch size {
        case .fixed(let points): content.font(.system(size: points, weight: weight, design: design)).monospacedDigit()
        case .style(let style): content.font(.system(style, design: design, weight: weight)).monospacedDigit()
        }
    }
}
