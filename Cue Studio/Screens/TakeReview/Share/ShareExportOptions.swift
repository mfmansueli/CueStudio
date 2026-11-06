//
//  ShareExportOptions.swift
//  Cue Studio
//

import SwiftUI

/// What the one export of "Share to universe" is made with: burned-in captions (and in which language) and the quality. The board's networks sheet has
/// room only for the networks, so these sit one tap away, behind the sliders in its corner. 4K is Cue Pro (owner, 06/11/2026): "4K · Pro" until then,
/// and a 4K recording says it exports in 1080p.
struct ShareExportOptions: View {
    @Bindable var review: TakeReviewViewModel

    /// The regular Pro, from "4K export is Cue Pro" › Go Pro.
    @State private var showsPro = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Export options").cueFont(.headline, weight: .semibold)
            GroupedCard(background: Palette.surface2, radius: 22) {
                Toggle("Burn in captions", isOn: $review.burnsInCaptions)
                    .tint(Palette.success)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .accessibilityIdentifier("share.captionsToggle")
                if review.burnsInCaptions, !review.captionTranslations.isEmpty {
                    Picker("Captions", selection: $review.exportCaptionDisplay) {
                        Text("Original").tag(CaptionDisplay.original)
                        ForEach(review.captionTranslations) { translation in
                            Text(verbatim: translation.language.nativeName).tag(CaptionDisplay.translation(translation.language))
                            Text("Both · \(translation.language.nativeName)").tag(CaptionDisplay.bilingual(translation.language))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .accessibilityIdentifier("share.captionLanguage")
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Quality")
                        Spacer()
                        Picker("Quality", selection: Binding(get: { review.exportQuality }, set: { review.setQuality($0) })) {
                            ForEach(ExportQuality.allCases) { Text(label(for: $0)).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .accessibilityIdentifier("share.quality")
                    }
                    if review.exportsFourKRecordingInHD {
                        Text("Recorded in 4K · exports in 1080p without Pro")
                            .cueFont(.footnote)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("share.qualityNote")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 52)
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 22, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
        .cueSheetChrome()
        // 4K without Pro: the system's alert says what Pro changes and what stays, with the regular Pro one tap away (no paywall of its own).
        .alert("4K export is Cue Pro", isPresented: $review.offersFourKPro) {
            Button("Go Pro") { showsPro = true }
            Button("Keep 1080p", role: .cancel) {}
        } message: {
            Text("Without Pro, this video exports in 1080p. Your recording and edit stay as they are.")
        }
        .fullScreenCover(isPresented: $showsPro) {
            PaywallView(context: .profile) { review.fourKProPurchased() }
        }
    }

    /// "4K · Pro" until the creator has Pro: the one thing in this sheet that Pro adds.
    private func label(for quality: ExportQuality) -> String {
        quality == .uhd4K && !review.isPro ? String(localized: "4K · Pro") : quality.label
    }
}
