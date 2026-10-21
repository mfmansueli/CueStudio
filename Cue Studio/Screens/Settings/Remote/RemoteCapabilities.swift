//
//  RemoteCapabilities.swift
//  Cue Studio
//

import SwiftUI

/// "From the remote you can": what the other device does to this teleprompter, four tiles in two columns. They rise into place one after
/// another; once a remote is connected (`isLive`) their icons light green in turn, left to right, top to bottom, as if switched on.
/// Reduce Motion: no rise, the colour changes at once.
struct RemoteCapabilities: View {
    var isLive = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var items: [(symbol: String, title: String)] {
        [
            ("playpause.fill", String(localized: "Play and pause")),
            ("gauge.with.dots.needle.67percent", String(localized: "Change speed")),
            ("arrow.up.arrow.down", String(localized: "Move through the script")),
            ("clock", String(localized: "See the progress")),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CueSectionHeader("From the remote you can")
                .padding(.horizontal, Metrics.textGutter)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    tile(item.symbol, item.title, index: index)
                }
            }
        }
        .onAppear { shown = true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("remote.capabilities")
    }

    private func tile(_ symbol: String, _ title: String, index: Int) -> some View {
        let beat = Double(index) * 0.07
        return HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isLive ? Palette.Remote.linkLive : Palette.Settings.generalGlyph)
                .frame(width: 24)
                .animation(reduceMotion ? nil : CueMotion.light(duration: 0.45).delay(isLive ? 0.75 + beat : 0), value: isLive)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .opacity(shown ? 1 : 0)
        .offset(y: shown || reduceMotion ? 0 : 10)
        .animation(reduceMotion ? CueMotion.fade : CueMotion.light(duration: 0.5).delay(0.15 + beat), value: shown)
    }
}
