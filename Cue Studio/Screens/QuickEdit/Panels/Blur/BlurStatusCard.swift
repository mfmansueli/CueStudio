//
//  BlurStatusCard.swift
//  Cue Studio
//

import SwiftUI

/// What a Blur area covers, first thing in its panel: following now (how far, Cancel), standing still (Follow), followed the
/// whole time (said only when nothing is left unchecked), or a stretch it may not cover, with Go there, Follow from here,
/// End here and It's right.
struct BlurStatusCard: View {
    let viewModel: QuickEditViewModel
    let region: BlurRegion

    var body: some View {
        let blur = viewModel.blur
        VStack(alignment: .leading, spacing: 10) {
            if let label = blur.followingLabel, blur.following?.id == region.id {
                following(label, progress: blur.following?.progress ?? 0)
            } else if let stretch = blur.focusedUnchecked {
                unchecked(stretch)
            } else if region.isCovered {
                header(symbol: "checkmark.circle.fill", tint: Palette.successText, title: String(localized: "Tracked the whole time"))
                PanelButton(label: String(localized: "Track again"), systemImage: "scope", identifier: "edit.blur.followAgain") { blur.follow() }
            } else {
                header(
                    symbol: "pin.fill", tint: Palette.ink2, title: String(localized: "Stays in place"),
                    detail: viewModel.edit.isOnPhoto(region) ? nil : String(localized: "Track it if what it hides moves.")
                )
                if !viewModel.edit.isOnPhoto(region) {
                    PanelButton(label: String(localized: "Track"), systemImage: "scope", isPrimary: true, identifier: "edit.blur.follow") { blur.follow() }
                }
            }
        }
        .padding(12)
        .editorCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.blur.status")
    }

    private func following(_ label: String, progress: Double) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("edit.blur.progress")
                ProgressView(value: progress).tint(Palette.acc)
            }
            Button(String(localized: "Cancel"), action: viewModel.blur.cancelFollowing)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .accessibilityHint(Text("Keeps what was tracked"))
                .accessibilityIdentifier("edit.blur.cancel")
        }
    }

    @ViewBuilder
    private func unchecked(_ stretch: TimeSpan) -> some View {
        let blur = viewModel.blur
        let shown = blur.editedSpan(ofFootage: stretch)
        let count = region.openUnchecked.count
        let place = shown.map { "\(DurationText.editor($0.start))–\(DurationText.editor($0.end))" } ?? ""
        header(
            symbol: "exclamationmark.triangle.fill", tint: Palette.warnText,
            title: String(localized: "Not tracked \(place) · \(DurationText.tenths(stretch.duration))"),
            detail: count > 1
                ? String(localized: "\(count) parts to check. It may not cover what it hides there: look, then fix it or say it's right.")
                : String(localized: "It may not cover what it hides there: look, then fix it or say it's right.")
        )
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            PanelButton(label: String(localized: "Go there"), isPrimary: true, identifier: "edit.blur.goThere") { blur.goToUnchecked() }
            PanelButton(label: String(localized: "Track from here"), identifier: "edit.blur.followHere") { blur.followFromHere() }
            PanelButton(label: String(localized: "End here"), identifier: "edit.blur.endHere") { blur.endHere() }
            PanelButton(label: String(localized: "It's right"), identifier: "edit.blur.checked") { blur.markChecked() }
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
        .accessibilityIdentifier("edit.blur.state")
    }
}
