//
//  ScriptSectionView.swift
//  Cue Studio
//

import SwiftUI

/// One section of the Shaped page: its label in mono on a rail (yellow for the hook, grey for the
/// rest, dashed when the section isn't written yet) and its words, cues as yellow tags.
struct ScriptSectionView: View {
    let section: ScriptShape.Section
    let tip: ScriptShape.Tip?
    let textSize: ScriptTextSize
    let onFix: (ScriptShape.Tip) -> Void
    let onDismiss: (ScriptShape.Tip) -> Void
    let onSuggestCTA: () -> Void
    let onHook: () -> Void

    @ScaledMetric(relativeTo: .body) private var labelWidth = 58.0

    private var railColor: Color {
        if section.isHook { return Palette.accText }
        return section.isMissingCTA ? Palette.ink3 : Palette.ink2
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(section.label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.6)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(railColor)
                .frame(width: labelWidth, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)
                .overlay(alignment: .trailing) { rail }
            VStack(alignment: .leading, spacing: 8) {
                if section.isMissingCTA {
                    Button(action: onSuggestCTA) {
                        Text("✦ No CTA yet · Suggest one")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.aiText)
                            .frame(minHeight: Metrics.hitTarget, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("page.suggestCTA")
                } else {
                    words
                }
                if let tip {
                    ScriptTipRow(tip: tip, onFix: { onFix(tip) }, onDismiss: { onDismiss(tip) })
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.section.\(section.firstParagraph)")
    }

    private var words: some View {
        Text(CueAttributedText.make(section.text, cueFont: .caption2.weight(.bold)))
            .font(.system(size: textSize.points + (section.isHook ? 0.5 : 0), weight: section.isHook ? .semibold : .regular))
            .lineSpacing(5)
            .foregroundStyle(section.isHook ? Palette.ink : Palette.ink.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { if section.isHook { onHook() } }
            .accessibilityAddTraits(section.isHook ? .isButton : [])
            .accessibilityHint(section.isHook ? Text("Pick a new hook") : Text(""))
            .accessibilityIdentifier("page.sectionText.\(section.firstParagraph)")
    }

    /// The rail's 2 pt line, solid or dashed.
    private var rail: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 1, y: 0))
                path.addLine(to: CGPoint(x: 1, y: proxy.size.height))
            }
            .stroke(railColor, style: StrokeStyle(lineWidth: 2, dash: section.isMissingCTA ? [4, 3] : []))
        }
        .frame(width: 2)
    }
}
