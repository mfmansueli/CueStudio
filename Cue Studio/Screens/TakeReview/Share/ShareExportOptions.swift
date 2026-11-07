//
//  ShareExportOptions.swift
//  Cue Studio
//

import SwiftUI

/// What the video's exports are made with: burned-in captions (and in which language) and the quality. One component and one state for every
/// way out (D11): Ready to travel's "Options · 1080p", the review's quiet line under Share (for Save) and the editor's Done open it, all on
/// the review's `TakeReviewViewModel`. The captions start from the editor; a choice that differs from it says it is for the export only, and
/// the saved edit never changes. 4K is Cue Pro (owner, 06/11/2026): "4K · Pro" until then, and a 4K recording says it exports in 1080p. Only a
/// 4K recording has a quality to pick; any other shows its own.
struct ShareExportOptions: View {
    @Bindable var review: TakeReviewViewModel
    /// The version the options are about: the saved edit, or the one the editor's Done is about to save.
    let edit: TakeEdit?

    /// The regular Pro, from "4K export is Cue Pro" › Go Pro.
    @State private var showsPro = false

    var body: some View {
        VStack(spacing: 14) {
            Text("Export options").cueFont(.headline, weight: .semibold)
            GroupedCard(background: Palette.surface2, radius: 22) {
                Toggle("Burn in captions", isOn: captionsBinding)
                    .tint(Palette.success)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .accessibilityIdentifier("share.captionsToggle")
                if review.output(for: edit).burnsInCaptions, let translations = edit?.captionTranslations, !translations.isEmpty {
                    Picker("Captions", selection: languageBinding) {
                        Text("Original").tag(CaptionDisplay.original)
                        ForEach(translations) { translation in
                            Text(verbatim: translation.language.nativeName).tag(CaptionDisplay.translation(translation.language))
                            Text("Both · \(translation.language.nativeName)").tag(CaptionDisplay.bilingual(translation.language))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .accessibilityIdentifier("share.captionLanguage")
                }
                if review.choosesQuality { qualityPicker } else { recordedQuality }
            }
            if let difference = review.outputDifference(for: edit) {
                // Only the export changes: said where the choice is made.
                Text(difference.text)
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("share.outputDifference")
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

    private var captionsBinding: Binding<Bool> {
        Binding(get: { review.output(for: edit).burnsInCaptions }, set: { shown in
            var choice = review.output(for: edit)
            choice.burnsInCaptions = shown
            review.setOutput(choice, for: edit)
        })
    }

    private var languageBinding: Binding<CaptionDisplay> {
        Binding(get: { review.output(for: edit).captionDisplay }, set: { display in
            var choice = review.output(for: edit)
            choice.captionDisplay = display
            review.setOutput(choice, for: edit)
        })
    }

    /// A 4K recording: 1080p or 4K (4K is Pro).
    private var qualityPicker: some View {
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

    /// A 1080p or 720p recording: its own resolution, nothing to pick (the file is never made larger than the recording).
    private var recordedQuality: some View {
        HStack {
            Text("Quality")
            Spacer()
            Text(verbatim: review.recordedResolutionLabel)
                .foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("share.qualityRecorded")
    }

    /// "4K · Pro" until the creator has Pro: the one thing in this sheet that Pro adds.
    private func label(for quality: ExportQuality) -> String {
        quality == .uhd4K && !review.isPro ? String(localized: "4K · Pro") : quality.label
    }
}
