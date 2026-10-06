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
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Palette.ink)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)
            Text(video.take.scriptTitle)
                .font(.system(size: 19))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 24)
            Text(detailLine)
                .font(CueStudioFont.hud)
                .tracking(1)
                .foregroundStyle(Palette.inkHint)
                .padding(.top, 8)
            Spacer(minLength: 12)
            exportsCard(left: review.exportsLeft).padding(.horizontal, 16)
            buttons
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
        }
        .skyBackground(wash: BgWash.share)
        .accessibilityElement(children: .contain)
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
                .font(CueStudioFont.hud)
                .tracking(1.5)
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
                    .font(CueStudioFont.hud)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Palette.posterPill, in: Capsule())
                    .padding(12)
            }
            .shadow(color: Palette.acc.opacity(0.15), radius: 30)
            .accessibilityHidden(true)
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
            HStack(spacing: 6) {
                if left != nil {
                    Text("FREE EXPORTS").foregroundStyle(Palette.ink2)
                    Text("·").foregroundStyle(Palette.inkHint)
                }
                Text(label.text).foregroundStyle(tint)
            }
            .font(CueStudioFont.hud)
            .tracking(1)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
                Button {} label: { Label("Saved to Photos", systemImage: "checkmark") }
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
