//
//  ShareExportOptions.swift
//  Cue Studio
//

import SwiftUI

/// What the one export of "Share to universe" is made with: burned-in captions (and in which language) and the quality. The board's networks sheet has
/// room only for the networks, so these sit one tap away, behind the sliders in its corner.
struct ShareExportOptions: View {
    @Bindable var review: TakeReviewViewModel

    var body: some View {
        VStack(spacing: 14) {
            Text("Export options").font(.headline)
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
                HStack {
                    Text("Quality")
                    Spacer()
                    Picker("Quality", selection: Binding(get: { review.quality }, set: { review.setQuality($0) })) {
                        ForEach(ExportQuality.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .accessibilityIdentifier("share.quality")
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 22, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
        .cueSheetChrome()
    }
}
