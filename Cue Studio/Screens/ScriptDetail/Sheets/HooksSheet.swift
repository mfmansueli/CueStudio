//
//  HooksSheet.swift
//  Cue Studio
//

import SwiftUI

/// Swap the opening line for a stronger hook.
struct HooksSheet: View {
    let currentHook: String
    let options: [String]
    let speed: Double
    let onPick: (String) -> Void
    let onMore: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SheetHeader(
                    title: String(localized: "Pick a new hook"),
                    subtitle: String(localized: "Viewers decide in the first 3 seconds."),
                    onClose: { dismiss() }
                )
                .padding(.bottom, 4)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Current")
                        Spacer()
                        Text("~\(DurationText.short(ReadTime.seconds(for: currentHook, speed: speed)))")
                            .foregroundStyle(Palette.warn)
                    }
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                    Text(currentHook.isEmpty ? String(localized: "No opening line yet") : CueParser.stripCues(currentHook))
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink.opacity(0.7))
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Palette.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                GroupedCard(background: Palette.surface2, radius: 22) {
                    ForEach(options, id: \.self) { hook in
                        Button { onPick(hook) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(CueParser.stripCues(hook))
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Palette.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("~\(DurationText.short(ReadTime.seconds(for: hook, speed: speed)))")
                                    .font(.footnote.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Palette.acc)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button(action: onMore) {
                    Label("More options", systemImage: "sparkles")
                        .foregroundStyle(Palette.acc)
                }
                .buttonStyle(.cueOutline())
                .padding(.top, 2)
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surface)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        HooksSheet(
            currentHook: "Okay, real talk. [pause] Three tiny habits completely changed my mornings.",
            options: ScriptStructure.generic.hooks.prefix(3).map { $0 },
            speed: 1, onPick: { _ in }, onMore: {}
        )
    }
}
#endif
