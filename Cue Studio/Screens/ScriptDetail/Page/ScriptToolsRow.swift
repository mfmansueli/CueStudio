//
//  ScriptToolsRow.swift
//  Cue Studio
//

import SwiftUI

/// The script page's tools, on one line over the words: Hook and Improve (the ways into the sheets of 4.3 and 4.4), "✦ Shape" beside
/// Improve while the words have no cues, and Cues, which turns the cue tags on the page on or off; then the text size, round, at the end.
/// The tools scroll sideways, each pill at its own width, so none is ever squeezed or cut at any width or text size (owner, 31/10/2026:
/// Shape came here from the state strip, where it cut "Ready to record" short). The row runs to the screen's leading edge and its first
/// pill starts on the page's gutter, in line with the words; a pill scrolling out fades before the edge and before the text size. The
/// text size stays put at the end: it sets how the page reads rather than changing the words, and it stays where the eye finds it
/// however many tools there are.
struct ScriptToolsRow: View {
    /// Improve is there: Apple Intelligence runs, or Ultra AI wrote the script (it keeps Improve for its Fit to time).
    let offersImprove: Bool
    /// "✦ Shape" is there (`ScriptStrip.canShape`, and the AI isn't writing).
    let offersShape: Bool
    @Binding var showsCues: Bool
    let onHook: () -> Void
    let onImprove: () -> Void
    let onShape: () -> Void
    let onTextSize: () -> Void

    /// How far a pill fades before the text size; also the room after the last one once the row has scrolled to its end.
    private static let fade: CGFloat = 14
    /// The pills' own height, inside their 44 pt hit target.
    private static let pillHeight: CGFloat = 34

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    pillButton("Hook", systemImage: "text.quote", ink: Palette.ink, fill: Palette.fill, action: onHook)
                        .accessibilityIdentifier("page.hookButton")
                    if offersImprove {
                        pillButton("Improve", systemImage: "sparkles", ink: Palette.aiTextStrong, fill: Palette.aiFill, action: onImprove)
                            .accessibilityIdentifier("page.improveButton")
                    }
                    if offersShape {
                        pillButton("Shape", systemImage: "sparkles", ink: Palette.aiTextStrong, fill: Palette.aiFill, action: onShape)
                            .accessibilityIdentifier("page.shapeButton")
                    }
                    cuesToggle
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.leading, Metrics.textGutter, for: .scrollContent)
            .contentMargins(.trailing, Self.fade, for: .scrollContent)
            .mask(edgeFade)
            textSizeButton
        }
        // Out to the screen's edge, so a pill scrolls off it rather than stopping short at the gutter.
        .padding(.leading, -Metrics.textGutter)
    }

    /// "Cues": on (yellow, like the tags), the page draws the cue tags; off, it shows only the words. The cues stay in the script
    /// either way.
    private var cuesToggle: some View {
        Toggle(isOn: $showsCues) {
            pill("Cues", systemImage: showsCues ? "eye" : "eye.slash", isOn: showsCues,
                 ink: showsCues ? Palette.accText : Palette.ink2, fill: showsCues ? Palette.accSoft : Palette.fill)
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Show cues"))
        .accessibilityIdentifier("page.cuesToggle")
    }

    /// Text size, as round as the tools beside it are long.
    private var textSizeButton: some View {
        Button(action: onTextSize) {
            Image(systemName: "textformat.size")
                .font(.fixed(14, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: Self.pillHeight, height: Self.pillHeight)
                .background(Palette.fill, in: Circle())
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Text size"))
        .accessibilityIdentifier("page.textSizeButton")
    }

    /// Clear at the screen's edge and just before the text size, opaque between: the leading fade lies over the gutter only, so the
    /// first pill is whole until it scrolls.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: Metrics.textGutter)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: Self.fade)
        }
    }

    private func pillButton(
        _ title: LocalizedStringKey, systemImage: String, ink: Color, fill: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            pill(title, systemImage: systemImage, isOn: false, ink: ink, fill: fill)
        }
        .buttonStyle(.plain)
    }

    /// One tool: its symbol and its name on one line, never cut (the row scrolls instead).
    private func pill(_ title: LocalizedStringKey, systemImage: String, isOn: Bool, ink: Color, fill: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).cueFont(12, weight: .bold).symbolSwap(value: isOn)
            Text(title)
        }
        .cueFont(14, weight: .semibold)
        .foregroundStyle(ink)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: Self.pillHeight)
        .background(fill, in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Capsule())
    }
}

#if DEBUG
#Preview {
    @Previewable @State var showsCues = true
    ScriptToolsRow(
        offersImprove: true, offersShape: true, showsCues: $showsCues,
        onHook: {}, onImprove: {}, onShape: {}, onTextSize: {}
    )
    .padding(.horizontal, Metrics.textGutter)
    .background(Palette.surface)
}
#endif
