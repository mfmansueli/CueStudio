//
//  InterfaceType.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The interface's type: every size of the boards (15.5 pt semibold, a 10 pt label…) drawn at that size at the default text size, grown with
/// Dynamic Type on the curve of the text style nearest to it (a small label grows less than a title, as the system's do) and following the
/// iPhone's width a little (`ScreenProportion`). Screens use `cueFont(_:weight:design:)`, or `cueFont(_ style:)` for a text style; a size
/// that must not grow (the prompter's words, words on the video, a miniature, a drawing) is `Font.fixed`, so it reads as a choice. A screen
/// whose bar or chip can't grow past a point caps it with `dynamicTypeSize(...)`, and every size here follows the cap.
nonisolated enum InterfaceType {
    /// The text style whose curve a size of `points` grows on: the one whose default size is nearest.
    static func style(for points: CGFloat) -> Font.TextStyle {
        switch points {
        case ..<11.5: .caption2
        case ..<12.5: .caption
        case ..<14: .footnote
        case ..<15.5: .subheadline
        case ..<16.5: .callout
        case ..<18.5: .body
        case ..<21: .title3
        case ..<25: .title2
        case ..<31: .title
        default: .largeTitle
        }
    }

    /// The default size of a text style (at the Large text size), the board's size for `cueFont(_ style:)`.
    static func defaultSize(of style: Font.TextStyle) -> CGFloat {
        UIFont.preferredFont(forTextStyle: style.uiTextStyle, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
    }

    /// `points` grown for `dynamicTypeSize` on `style`'s curve, at `proportion` of the board's size.
    static func size(
        _ points: CGFloat, relativeTo style: Font.TextStyle? = nil, for dynamicTypeSize: DynamicTypeSize, proportion: CGFloat = 1
    ) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let metrics = UIFontMetrics(forTextStyle: (style ?? self.style(for: points)).uiTextStyle)
        return metrics.scaledValue(for: points * proportion, compatibleWith: traits)
    }
}

extension View {
    /// Type at the board's `size`, growing with the text size and following the iPhone's width (`InterfaceType`).
    func cueFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(InterfaceFont(points: size, style: nil, weight: weight, design: design))
    }

    /// A text style at its default size, grown on its own curve and following the iPhone's width (`InterfaceType`).
    func cueFont(_ style: Font.TextStyle, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(InterfaceFont(points: InterfaceType.defaultSize(of: style), style: style, weight: weight, design: design))
    }
}

extension Font {
    /// `cueFont` where a `Font` is asked for (a `Text` joined to another, a parameter): sized for the view's `dynamicTypeSize`.
    @MainActor static func cue(
        _ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, for dynamicTypeSize: DynamicTypeSize
    ) -> Font {
        .system(size: InterfaceType.size(size, for: dynamicTypeSize, proportion: ScreenProportion.current), weight: weight, design: design)
    }

    /// A size that deliberately doesn't grow with the text size or the screen: the prompter's words (its own slider sets them), words
    /// drawn on the video, a miniature of a screen, a share card drawn as a picture.
    static func fixed(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

extension Font.TextStyle {
    nonisolated var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}

/// `cueFont`.
private struct InterfaceFont: ViewModifier {
    let points: CGFloat
    let style: Font.TextStyle?
    let weight: Font.Weight
    let design: Font.Design
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let size = InterfaceType.size(points, relativeTo: style, for: dynamicTypeSize, proportion: ScreenProportion.current)
        content.font(.system(size: size, weight: weight, design: design))
    }
}
