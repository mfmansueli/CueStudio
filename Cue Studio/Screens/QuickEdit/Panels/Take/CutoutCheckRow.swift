//
//  CutoutCheckRow.swift
//  Cue Studio
//

import SwiftUI

/// Check the cutout, in Background's Cutout card while the automatic cutout is in use: reads the video for the moments where Cue loses
/// the creator (longer than their last outline is held), says how far it got (Stop keeps nothing), and then either that it found
/// them in every frame or each moment as a time to go to.
struct CutoutCheckRow: View {
    @Bindable var viewModel: QuickEditViewModel

    /// Moments shown as buttons; more are counted.
    private static let shownMoments = 6

    var body: some View {
        let look = viewModel.look
        VStack(alignment: .leading, spacing: 10) {
            switch look.shownCutoutCheck {
            case .idle:
                idle(again: false)
            case .failed:
                header(symbol: "exclamationmark.triangle.fill", tint: Palette.warnText, title: String(localized: "Couldn't read the video"))
                idle(again: true)
            case .checking(let progress):
                checking(progress)
            case .checked(let misses, _) where misses.isEmpty:
                header(symbol: "checkmark.circle.fill", tint: Palette.successText, title: String(localized: "Found you in every frame"))
            case .checked(let misses, _):
                found(misses)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.cutoutCheck")
    }

    private func idle(again: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelButton(
                label: again ? String(localized: "Check again") : String(localized: "Check the cutout"), systemImage: "person.crop.rectangle",
                identifier: "edit.cutoutCheckButton"
            ) { viewModel.look.checkCutout() }
            PanelNote(text: String(localized: "Finds the moments where Cue loses you, so you can look at them."))
        }
    }

    private func checking(_ progress: Double) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Checking the cutout · \(Int((progress * 100).rounded()))%")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("edit.cutoutCheckProgress")
                ProgressView(value: progress).tint(Palette.acc)
            }
            Button(String(localized: "Stop"), action: viewModel.look.cancelCutoutCheck)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("edit.cutoutCheckStop")
        }
    }

    @ViewBuilder
    private func found(_ misses: [TimeSpan]) -> some View {
        header(
            symbol: "exclamationmark.triangle.fill", tint: Palette.warnText, title: String(localized: "Cue lost you in \(misses.count) moments"),
            detail: String(localized: "There Cue keeps your last outline for half a second, then the original background can show.")
        )
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(misses.prefix(Self.shownMoments).enumerated()), id: \.offset) { index, miss in
                PanelButton(
                    label: DurationText.clock(miss.start), systemImage: "arrow.right.circle", isCompact: true,
                    identifier: "edit.cutoutMiss.\(index)"
                ) { viewModel.look.goToCutoutMiss(miss) }
                .accessibilityLabel(Text("Go to \(DurationText.clock(miss.start))"))
            }
        }
        if misses.count > Self.shownMoments {
            PanelNote(text: String(localized: "And \(misses.count - Self.shownMoments) more"))
        }
    }

    private func header(symbol: String, tint: Color, title: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.editorGlyph(EditorGlyph.compact, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.system(.caption))
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.cutoutCheckState")
    }
}
