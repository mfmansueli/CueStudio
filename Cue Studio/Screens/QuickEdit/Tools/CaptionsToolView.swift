//
//  CaptionsToolView.swift
//  Cue Studio
//

import SwiftUI

/// Captions made from what is said in the take, then read and corrected line by line: the switch,
/// the language spoken, where listening is (with Stop), the type presets and position, and the
/// lines. A take no model can hear can still be captioned by hand.
struct CaptionsToolView: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(spacing: 10) {
            header
            status
            ScrollView {
                VStack(spacing: 10) {
                    presets
                    Picker("Position", selection: $viewModel.edit.captionPosition) {
                        ForEach(CaptionPosition.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    lines
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { viewModel.edit.showsCaptions },
                set: { shows in Task { await viewModel.setShowsCaptions(shows) } }
            )) {
                Text("Captions")
            }
            .tint(Palette.success)
            .fixedSize()
            .accessibilityIdentifier("edit.captionsToggle")
            Spacer(minLength: 4)
            languageMenu
            Button {
                viewModel.makeCaptions()
            } label: {
                Image(systemName: viewModel.edit.captions.isEmpty ? "waveform" : "arrow.clockwise")
            }
            .buttonStyle(.cueIcon(.surface, diameter: Metrics.compactButtonHeight))
            .disabled(viewModel.captionState.isWorking)
            .accessibilityLabel(Text(viewModel.edit.captions.isEmpty ? "Make captions from your voice" : "Make the captions again"))
            .accessibilityIdentifier("edit.captionsMakeButton")
        }
        .frame(minHeight: Metrics.hitTarget)
        .confirmationDialog(
            "Replace your edited captions?",
            isPresented: $viewModel.confirmsCaptionReplacement,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) { viewModel.makeCaptions(replacingRevised: true) }
                .accessibilityIdentifier("edit.captionsReplaceButton")
            Button("Keep mine", role: .cancel) {}
        } message: {
            Text("New captions from your voice replace the lines you corrected or wrote.")
        }
    }

    /// The language spoken in the take: automatic (Voice Following's or the script's) or picked.
    private var languageMenu: some View {
        Menu {
            Picker("Spoken language", selection: Binding(
                get: { viewModel.edit.captionLanguage },
                set: { viewModel.setCaptionLanguage($0) }
            )) {
                Text("Automatic").tag(CueLanguage?.none)
                ForEach(CueLanguage.allCases) { language in
                    Text(verbatim: language.nativeName).tag(Optional(language))
                }
            }
        } label: {
            FilterChip(
                label: viewModel.edit.captionLanguage?.nativeName ?? String(localized: "Automatic"),
                isSelected: false, systemImage: "globe", height: Metrics.compactButtonHeight
            )
        }
        .accessibilityLabel(Text("Spoken language"))
        .accessibilityValue(Text(viewModel.edit.captionLanguage?.nativeName ?? String(localized: "Automatic")))
        .accessibilityIdentifier("edit.captionsLanguage")
    }

    @ViewBuilder
    private var status: some View {
        if let message = viewModel.captionState.message {
            HStack(spacing: 10) {
                if viewModel.captionState.isWorking {
                    ProgressView().controlSize(.small)
                }
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("edit.captionsStatus")
                if viewModel.captionState.isWorking {
                    Button("Stop") { viewModel.cancelCaptions() }
                        .buttonStyle(.cueSecondary(.compact, expands: false))
                        .accessibilityIdentifier("edit.captionsStopButton")
                } else if viewModel.captionState.canRetry {
                    Button("Try again") { viewModel.makeCaptions() }
                        .buttonStyle(.cueSecondary(.compact, expands: false))
                        .accessibilityIdentifier("edit.captionsRetryButton")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
        }
    }

    private var presets: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(TypePreset.allCases) { preset in
                    let isOn = viewModel.edit.captionPreset == preset
                    Button {
                        Task { await viewModel.setCaptionPreset(preset) }
                    } label: {
                        captionSample(preset)
                            .frame(width: 112, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(preset.label))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("edit.captionPreset.\(preset.rawValue)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Each line with when it plays; tapping one shows it on the preview and opens it.
    private var lines: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.editedCaptionLines) { line in
                Button {
                    viewModel.showCaption(line.id)
                    viewModel.editingCaptionID = line.id
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(DurationText.timecode(line.start, total: viewModel.edit.editedDuration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Palette.ink2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(line.text.isEmpty ? String(localized: "Empty line") : line.text)
                                .font(.subheadline)
                                .foregroundStyle(line.text.isEmpty ? Palette.ink3 : Palette.ink)
                                .multilineTextAlignment(.leading)
                            flags(line)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("edit.captionLine")
            }
            Button {
                viewModel.addCaption()
            } label: {
                Label("Add a line", systemImage: "plus")
            }
            .buttonStyle(.cueSecondary(.compact))
            .accessibilityIdentifier("edit.captionsAddButton")
        }
    }

    @ViewBuilder
    private func flags(_ line: CaptionCue) -> some View {
        let revised = line.isRevised || line.origin == .manual
        if revised || line.needsTimingReview {
            HStack(spacing: 6) {
                if line.origin == .manual {
                    TagPill(text: String(localized: "Written by you"))
                } else if line.isRevised {
                    TagPill(text: String(localized: "Edited"))
                }
                if line.needsTimingReview {
                    TagPill(text: String(localized: "Check timing"), dotColor: Palette.warn)
                }
            }
        }
    }

    /// The preset drawn on captions exactly as the export draws them.
    private func captionSample(_ preset: TypePreset) -> some View {
        ZStack {
            LinearGradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom], startPoint: .top, endPoint: .bottom)
            if let image = TypeLookPreview.image(preset.look(for: .caption), use: .caption, sample: preset.label) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
        }
    }
}
