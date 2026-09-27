//
//  DisplaySettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Aa": how the prompter reads, with a live preview behind the sheet. Quick settings first,
/// the rest under Advanced. Over the Selfie camera the sheet never covers the script panel.
struct DisplaySettingsSheet: View {
    let mode: PrompterMode
    /// Tallest the sheet may grow in Selfie mode, so the script above stays in sight.
    var maxHeight: CGFloat?

    @Environment(PreferencesService.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var showsAdvanced = false

    /// The medium detent, as in the design.
    private static let compactHeight: CGFloat = 330

    var body: some View {
        @Bindable var preferences = preferences
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(text: String(localized: "Quick"))
                        .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
                    toggleRow(
                        String(localized: "AI Coach"),
                        detail: String(localized: "Performance cues like PAUSE or SMILE"),
                        isOn: $preferences.prompter.showsCues
                    )
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityIdentifier("display.aiCoachToggle")
                    quickSliders
                    if mode == .selfie {
                        Text("Background and blur only change your preview — never the recording.")
                            .font(.caption)
                            .foregroundStyle(Palette.ink.opacity(0.45))
                            .padding(.horizontal, 4)
                    }
                    advancedToggle
                    if showsAdvanced {
                        advanced
                    }
                }
                .padding(EdgeInsets(top: 0, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
                .animation(.smooth(duration: 0.25), value: showsAdvanced)
            }
        }
        .presentationDetents(detents)
        .presentationBackground(Palette.sheetGlass)
        .presentationCornerRadius(32)
        .presentationBackgroundInteraction(.enabled)
    }

    private var detents: Set<PresentationDetent> {
        guard let maxHeight else { return [.height(Self.compactHeight), .large] }
        return [.height(min(Self.compactHeight, maxHeight)), .height(maxHeight)]
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Display").font(.title3.bold())
            HStack(spacing: 5) {
                Circle().fill(Palette.live).frame(width: 6, height: 6)
                Text("Live preview")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.ink2)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.cuePrimary(.compact, expands: false))
                .accessibilityIdentifier("display.doneButton")
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 10, trailing: 16))
    }

    private var quickSliders: some View {
        @Bindable var preferences = preferences
        return GroupedCard(background: Palette.surface2, radius: 22) {
            ValueSlider(
                title: String(localized: "Text size"),
                valueText: "\(Int(preferences.prompter.size))",
                value: $preferences.prompter.size,
                range: PrompterSettings.sizeRange
            )
            .padding(.horizontal, 16)
            if mode == .selfie {
                ValueSlider(
                    title: String(localized: "Reading width"),
                    valueText: preferences.prompter.readingWidth.formatted(.percent.precision(.fractionLength(0))),
                    value: $preferences.prompter.readingWidth,
                    range: PrompterPanelLayout.widthRange, step: 0.01,
                    ends: (String(localized: "Narrow"), String(localized: "Wide")),
                    identifier: "display.readingWidth"
                )
                .padding(.horizontal, 16)
            }
            ValueSlider(
                title: String(localized: "Reading line"),
                valueText: preferences.prompter.guidePosition.formatted(.percent.precision(.fractionLength(0))),
                value: $preferences.prompter.guidePosition,
                range: PrompterSettings.guideRange, step: 0.01,
                ends: (String(localized: "Top"), String(localized: "Bottom"))
            )
            .padding(.horizontal, 16)
            if mode == .selfie {
                ValueSlider(
                    title: String(localized: "Background opacity"),
                    valueText: preferences.prompter.backgroundOpacity.formatted(.percent.precision(.fractionLength(0))),
                    value: $preferences.prompter.backgroundOpacity,
                    range: PrompterSettings.backgroundOpacityRange, step: 0.05
                )
                .padding(.horizontal, 16)
                ValueSlider(
                    title: String(localized: "Camera blur"),
                    valueText: preferences.prompter.cameraBlurLabel,
                    value: $preferences.prompter.cameraBlur,
                    range: PrompterSettings.cameraBlurRange
                )
                .padding(.horizontal, 16)
            } else {
                row(String(localized: "Background color")) {
                    HStack(spacing: 0) {
                        ForEach(StudioBackground.allCases) { option in
                            SwatchButton(color: option.color, isSelected: preferences.prompter.studioBackground == option, accessibilityName: option.label) {
                                preferences.prompter.studioBackground = option
                            }
                        }
                    }
                }
            }
        }
    }

    private var advancedToggle: some View {
        Button {
            showsAdvanced.toggle()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Advanced").font(.body.weight(.semibold))
                    Text("Font, spacing, margins, alignment, color")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.ink.opacity(0.5))
                    .rotationEffect(.degrees(showsAdvanced ? 90 : 0))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityValue(showsAdvanced ? Text("Expanded") : Text("Collapsed"))
        .accessibilityIdentifier("display.advancedButton")
    }

    @ViewBuilder
    private var advanced: some View {
        @Bindable var preferences = preferences
        fontPicker
        GroupedCard(background: Palette.surface2, radius: 22) {
            ValueSlider(
                title: String(localized: "Line spacing"),
                valueText: preferences.prompter.lineSpacing.formatted(.number.precision(.fractionLength(2))),
                value: $preferences.prompter.lineSpacing,
                range: PrompterSettings.lineSpacingRange, step: 0.05
            )
            .padding(.horizontal, 16)
            ValueSlider(
                title: String(localized: "Side margins"),
                valueText: String(localized: "\(Int(preferences.prompter.margin)) pt"),
                value: $preferences.prompter.margin,
                range: PrompterSettings.marginRange, step: 2
            )
            .padding(.horizontal, 16)
            row(String(localized: "Alignment")) {
                Picker("Alignment", selection: $preferences.prompter.alignment) {
                    ForEach(PrompterAlignment.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            row(String(localized: "Text color")) {
                HStack(spacing: 0) {
                    ForEach(PrompterTextColor.allCases) { option in
                        SwatchButton(color: option.color, isSelected: preferences.prompter.textColor == option, accessibilityName: option.label) {
                            preferences.prompter.textColor = option
                        }
                    }
                }
            }
        }
        GroupedCard(background: Palette.surface2, radius: 22) {
            toggleRow(String(localized: "Show reading line"), isOn: $preferences.prompter.showsGuide)
            toggleRow(String(localized: "Mirror text"), detail: String(localized: "For beam-splitter glass rigs"), isOn: $preferences.prompter.isMirrored)
        }
    }

    private var fontPicker: some View {
        HStack(spacing: 8) {
            ForEach(PrompterFont.allCases) { font in
                Button {
                    preferences.prompter.font = font
                } label: {
                    SelectableCard(isSelected: preferences.prompter.font == font, radius: 14) {
                        VStack(spacing: 4) {
                            Text("Aa").font(font.font(size: 22))
                            Text(font.label).font(.caption2).foregroundStyle(Palette.ink2)
                        }
                        .frame(height: 66)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(font.label))
                .accessibilityAddTraits(preferences.prompter.font == font ? .isSelected : [])
            }
        }
    }

    // MARK: - Rows

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            content()
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 16)
    }

    private func toggleRow(_ title: String, detail: String? = nil, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
        }
        .tint(Palette.success)
        .frame(minHeight: 58)
        .padding(.horizontal, 16)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        DisplaySettingsSheet(mode: .selfie)
    }
    .previewEnvironment()
}
#endif
