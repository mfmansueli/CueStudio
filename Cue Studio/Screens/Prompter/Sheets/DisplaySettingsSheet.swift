//
//  DisplaySettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// How the prompter looks and scrolls. The text stays visible behind the sheet at its first height.
struct DisplaySettingsSheet: View {
    let mode: PrompterMode

    @Environment(PreferencesService.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var preferences = preferences
        VStack(spacing: 0) {
            HStack {
                Text("Display").font(.title3.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.cuePrimary(.compact, expands: false))
                    .accessibilityIdentifier("display.doneButton")
            }
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 8, trailing: 16))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    fontPicker
                    GroupedCard(background: Palette.surface2, radius: 22) {
                        ValueSlider(
                            title: String(localized: "Text size"),
                            valueText: "\(Int(preferences.prompter.size))",
                            value: $preferences.prompter.size,
                            range: PrompterSettings.sizeRange
                        )
                        .padding(.horizontal, 16)
                        ValueSlider(
                            title: String(localized: "Line spacing"),
                            valueText: preferences.prompter.lineSpacing.formatted(.number.precision(.fractionLength(2))),
                            value: $preferences.prompter.lineSpacing,
                            range: PrompterSettings.lineSpacingRange, step: 0.05
                        )
                        .padding(.horizontal, 16)
                        ValueSlider(
                            title: String(localized: "Side margins"),
                            valueText: "\(Int(preferences.prompter.margin))",
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

                    SectionHeading(text: String(localized: "Background"))
                        .padding(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
                    GroupedCard(background: Palette.surface2, radius: 22) {
                        if mode == .selfie {
                            ValueSlider(
                                title: String(localized: "Dim behind text"),
                                valueText: preferences.prompter.dim.formatted(.percent.precision(.fractionLength(0))),
                                value: $preferences.prompter.dim,
                                range: PrompterSettings.dimRange, step: 0.05
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

                    SectionHeading(text: String(localized: "Reading"))
                        .padding(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
                    GroupedCard(background: Palette.surface2, radius: 22) {
                        VStack(alignment: .leading, spacing: 0) {
                            row(String(localized: "Scrolling")) {
                                Picker("Scrolling", selection: $preferences.prompter.scrollMode) {
                                    ForEach(ScrollMode.allCases) { Text($0.label).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .fixedSize()
                            }
                            if preferences.prompter.scrollMode == .voice {
                                Text("Listens as you read and keeps your line on the guide, at your pace. Waits when you pause or go off script. Recognition happens on this device.")
                                    .font(.footnote)
                                    .foregroundStyle(Palette.ink2)
                                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                                    .accessibilityIdentifier("display.voiceFollowNote")
                            }
                        }
                        VStack(spacing: 0) {
                            toggleRow(String(localized: "Reading guide"), isOn: $preferences.prompter.showsGuide)
                            if preferences.prompter.showsGuide {
                                ValueSlider(
                                    title: String(localized: "Guide position"),
                                    valueText: preferences.prompter.guidePosition.formatted(.percent.precision(.fractionLength(0))),
                                    value: $preferences.prompter.guidePosition,
                                    range: PrompterSettings.guideRange, step: 0.01
                                )
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                            }
                        }
                        toggleRow(String(localized: "Mirror text"), detail: String(localized: "For beam-splitter glass rigs"), isOn: $preferences.prompter.isMirrored)
                        toggleRow(String(localized: "Show cues"), detail: String(localized: "Stage cues like [pause] in the prompter"), isOn: $preferences.prompter.showsCues)
                    }
                }
                .padding(EdgeInsets(top: 6, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
            }
        }
        .presentationDetents([.height(480), .large])
        .presentationBackground(Palette.surface)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(480)))
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
            }
        }
    }

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
        .frame(minHeight: 52)
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
