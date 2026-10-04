//
//  ReadyToTravelView.swift
//  Cue Studio
//

import SwiftUI

/// The export is done: the video is in Photos, with no watermark, and what is left is choosing where it goes.
struct ReadyToTravelView: View {
    let video: ExportedVideo
    let onShare: (ShareDestination) -> Void
    let onOtherApps: () -> Void
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
            if let left = video.exportsLeft { exportsCard(left: left).padding(.horizontal, 16) }
            buttons
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
        }
        .skyBackground()
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
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.cueIcon(.glass, diameter: 40))
                    .accessibilityLabel(Text("Close"))
                    .accessibilityIdentifier("ready.closeButton")
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

    private func exportsCard(left: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let total = UsagePolicy.freeExports
        return HStack {
            HStack(spacing: 6) {
                Text("FREE EXPORTS").foregroundStyle(Palette.ink2)
                Text("·").foregroundStyle(Palette.inkHint)
                Text("\(left) OF \(total) LEFT").foregroundStyle(Palette.warnText)
            }
            .font(CueStudioFont.hud)
            .tracking(1)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index < total - left ? Palette.warn : Palette.fill)
                        .frame(width: 22, height: 7)
                }
            }
        }
        .padding(18)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Free exports left"))
        .accessibilityValue(Text("\(left) of \(total)"))
        .accessibilityIdentifier("ready.exportsLeft")
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if let platform = video.platform {
                Button { onShare(ShareDestination(platform)) } label: {
                    Label("Share to \(platform.label)", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("ready.shareButton")
            }
            HStack(spacing: 10) {
                Button {} label: {
                    Label { Text("Saved to Photos").lineLimit(1).minimumScaleFactor(0.7) } icon: { Image(systemName: "checkmark") }
                }
                    .buttonStyle(.cueSecondary(.large))
                    .disabled(true)
                    .accessibilityIdentifier("ready.savedButton")
                Button(action: onOtherApps) { Text("Other apps") }
                    .buttonStyle(video.platform == nil ? .cuePrimary(.large) : .cueSecondary(.large))
                    .accessibilityIdentifier("ready.otherAppsButton")
            }
        }
    }
}
