//
//  ReadyToTravelView.swift
//  Cue Studio
//

import SwiftUI

/// The video is made (1080 × 1920, no watermark) and nothing has left Cue yet (8.1): **Share to universe** (the networks, one after the other),
/// **Save video** (Photos) and the share icon (the system share sheet) are three ways out, and each counts one free export when the file leaves.
struct ReadyToTravelView: View {
    let video: ExportedVideo
    @Bindable var review: TakeReviewViewModel
    @Bindable var flow: ShareFlow
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            poster
                .padding(.top, 18)
            Text("Ready to travel.")
                .cueFont(36, weight: .bold)
                .foregroundStyle(Palette.ink)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)
            Text(video.take.scriptTitle)
                .cueFont(19)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 24)
            Text(detailLine)
                .hudFont()
                .interfaceTracking(1)
                .foregroundStyle(Palette.ink2)
                .padding(.top, 8)
            Spacer(minLength: 12)
            if let reason = video.missingCaptions {
                missingCaptions(reason).padding(.horizontal, 16).padding(.bottom, 10)
            }
            // An export from here failed (Save, the queue's file): the card with Try again stays on this cover, where it was asked for.
            if let failure = review.exportFailure {
                ExportFailedCard(
                    failure: failure, onRetry: { Task { await review.retryFailedExport() } }, onClose: review.dismissExportFailure
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            exportsCard(left: review.exportsLeft).padding(.horizontal, 16)
            buttons
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
        }
        .skyBackground(wash: BgWash.share)
        .accessibilityElement(children: .contain)
        // A scene with its words placed in it: the text grows up to the first accessibility size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityIdentifier("ready.sheet")
    }

    private var detailLine: String {
        var parts = [DurationText.clock(video.take.duration)]
        if video.hasCaptions { parts.append(String(localized: "CAPTIONS ON")) }
        parts.append(String(localized: "NO WATERMARK"))
        return parts.joined(separator: " · ")
    }

    // MARK: - Parts

    private var topBar: some View {
        ZStack {
            Text("EXPORTED · \(video.formatLabel)")
                .hudFont()
                .interfaceTracking(1.5)
                .foregroundStyle(Palette.successText)
            HStack {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.cueIcon(.glass, diameter: 40))
                    .accessibilityLabel(Text("Close"))
                    .accessibilityIdentifier("ready.closeButton")
                Spacer()
                Button { review.share(video) } label: { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.cueIcon(.glass, diameter: 40))
                    .accessibilityLabel(Text("Share"))
                    .accessibilityIdentifier("ready.shareIcon")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return TakeThumbnail(take: video.take)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxHeight: 400)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.acc.opacity(0.7), lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                Text(DurationText.clock(video.take.duration))
                    .hudFont()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(minHeight: 28)
                    .background(Palette.Takes.posterPill, in: Capsule())
                    .padding(12)
            }
            .shadow(color: Palette.acc.opacity(0.15), radius: 30)
            .accessibilityHidden(true)
    }

    /// Captions were asked for and the video has none: said here, on the cover, with why (the toast that said it hid under this cover).
    private func missingCaptions(_ reason: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.noticeRadius, style: .continuous)
        return HStack(spacing: 12) {
            Image(systemName: "captions.bubble")
                .cueFont(17, weight: .semibold)
                .foregroundStyle(Palette.warnText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No captions on this video")
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                Text(reason)
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ready.noCaptions")
    }

    private func exportsLabel(_ text: String, tint: Color, named: Bool) -> some View {
        HStack(spacing: 6) {
            if named {
                Text("FREE EXPORTS").foregroundStyle(Palette.ink2)
                Text("·").foregroundStyle(Palette.ink2)
            }
            Text(text).foregroundStyle(tint)
        }
        .hudFont()
        .interfaceTracking(1)
        .lineLimit(1)
        .fixedSize()
    }

    /// 8.1: the free exports left as a label ("2 OF 5 LEFT", "LAST FREE EXPORT" in yellow, "0 OF 5 LEFT · EXPORT WITH PRO" in orange) and the
    /// five bars; on Pro, "PRO · UNLIMITED EXPORTS".
    private func exportsCard(left: Int?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let total = UsagePolicy.freeExports
        let label = FreeExportLabels.meter(left: left)
        let tint: Color = switch label.tone {
        case .quiet: Palette.ink2
        case .last: Palette.accText
        case .exhausted: Palette.warnText
        }
        return HStack {
            // "FREE EXPORTS · 0 OF 3 LEFT · EXPORT WITH PRO" where it fits, the state alone where it doesn't: never a cut word (owner,
            // 02/11/2026).
            ViewThatFits(in: .horizontal) {
                exportsLabel(label.text, tint: tint, named: left != nil)
                exportsLabel(label.text, tint: tint, named: false)
            }
            .animation(.easeOut(duration: 0.25), value: label.tone)
            Spacer(minLength: 8)
            if let left {
                HStack(spacing: 5) {
                    ForEach(0..<total, id: \.self) { index in
                        Capsule()
                            .fill(index < total - left ? (left <= 1 ? Palette.acc : Palette.warn) : Palette.fill)
                            .frame(width: 22, height: 7)
                    }
                }
            }
        }
        .padding(18)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(left == nil ? "Unlimited exports" : "Free exports left"))
        .accessibilityValue(Text(left.map { "\($0) of \(total)" } ?? ""))
        .accessibilityIdentifier("ready.exportsLeft")
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button { flow.openPicker(with: video) } label: {
                Label("Share to universe", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.cuePrimary(.large))
            .accessibilityIdentifier("ready.shareButton")
            if review.isSaved(video) {
                Button {} label: {
                    Label(
                        review.savedCover(video) ? String(localized: "Video and cover saved") : String(localized: "Saved to Photos"),
                        systemImage: "checkmark"
                    )
                }
                    .buttonStyle(.cueSecondary(.large))
                    .disabled(true)
                    .accessibilityIdentifier("ready.savedButton")
            } else {
                Button { Task { await review.save() } } label: { Text("Save video") }
                    .buttonStyle(.cueSecondary(.large))
                    .accessibilityIdentifier("ready.saveButton")
            }
        }
        .disabled(review.runningAction != nil)
    }
}
