//
//  StartRecordingSheet.swift
//  Cue Studio
//

import SwiftUI

/// Before the camera: read from a recent script, start a new one, or record freestyle. In attach
/// mode it adds a script to a freestyle recording, so there is nothing to skip.
struct StartRecordingSheet: View {
    enum Mode { case new, attach }

    /// How many recent scripts are offered.
    static let recentLimit = 4

    let mode: Mode
    let recent: [Script]
    let readSeconds: (Script) -> TimeInterval
    let onPick: (Script) -> Void
    let onNewScript: () -> Void
    var onSkip: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: mode == .attach ? String(localized: "Add a script") : String(localized: "Start recording"),
                subtitle: mode == .attach
                    ? String(localized: "Cue will scroll it under the lens. Your camera stays where it is.")
                    : String(localized: "Scripts keep you on track and cut retakes. Pick one to read from."),
                onClose: { dismiss() }
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 16)

            if !recent.isEmpty {
                SectionHeading(text: String(localized: "Read from a script"))
                    .padding(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius, dividerInset: 34) {
                    ForEach(recent.prefix(Self.recentLimit)) { script in
                        recentRow(script)
                    }
                }
            }

            Button(action: onNewScript) {
                Label("New script", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.acc)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget + 4, alignment: .leading)
                    .padding(.horizontal, 14)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .accessibilityIdentifier("startRecording.newScript")

            if mode == .new {
                Button(action: onSkip) {
                    HStack(spacing: 10) {
                        Circle().fill(Palette.record).frame(width: 12, height: 12)
                        Text("Record without a script")
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                    }
                }
                .buttonStyle(.cueOutline(.large))
                .padding(.top, 18)
                .accessibilityIdentifier("startRecording.skip")
                Text("Freestyle now — add a script anytime from the camera.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
    }

    private func recentRow(_ script: Script) -> some View {
        Button { onPick(script) } label: {
            HStack(spacing: 12) {
                ColorDot(color: script.platform.tint, size: 8)
                Text(script.displayTitle)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("~\(DurationText.short(readSeconds(script)))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink2)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.hitTarget + 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("startRecording.recent.\(script.id.uuidString)")
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        StartRecordingSheet(
            mode: .new, recent: SampleScripts.all, readSeconds: { _ in 62 },
            onPick: { _ in }, onNewScript: {}, onSkip: {}
        )
    }
}
#endif
