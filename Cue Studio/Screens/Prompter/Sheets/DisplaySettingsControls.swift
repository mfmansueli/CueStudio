//
//  DisplaySettingsControls.swift
//  Cue Studio
//

import SwiftUI

/// The shared Aa editor. Bind to the session in the recorder or to defaults in Creator Setup.
/// Creator Setup already has size, line visibility and mirroring, so it omits those controls.
struct DisplaySettingsControls: View {
    @Binding var settings: PrompterSettings
    let mode: PrompterMode
    var showsCoreControls = true

    @Environment(\.layoutDirection) private var layoutDirection
    @State private var showsAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(text: String(localized: "Quick"))
                .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
            GroupedCard(background: Palette.surface2, radius: 22) {
                SettingToggleRow(
                    title: String(localized: "AI Coach"),
                    detail: String(localized: "Performance cues like PAUSE or SMILE"),
                    isOn: $settings.showsCues
                )
                .accessibilityIdentifier("display.aiCoachToggle")
            }
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
        .animation(.smooth(duration: 0.25), value: showsAdvanced)
    }

    /// Selfie: text size, then how the window sits on the camera. Studio: text size, where the
    /// line sits in the text, and the background color.
    private var quickSliders: some View {
        GroupedCard(background: Palette.surface2, radius: 22) {
            if showsCoreControls {
                ValueSlider(
                    title: String(localized: "Text size"),
                    valueText: "\(Int(settings.size))",
                    value: $settings.size,
                    range: PrompterSettings.sizeRange
                )
                .padding(.horizontal, 16)
            }
            if mode == .selfie {
                ValueSlider(
                    title: String(localized: "Background opacity"),
                    valueText: settings.backgroundOpacity.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
                    value: $settings.backgroundOpacity,
                    range: PrompterSettings.backgroundOpacityRange, step: 0.05,
                    identifier: "display.backgroundOpacity"
                )
                .padding(.horizontal, 16)
                ValueSlider(
                    title: String(localized: "Camera blur"),
                    valueText: settings.cameraBlurLabel,
                    value: $settings.cameraBlur,
                    range: PrompterSettings.cameraBlurRange
                )
                .padding(.horizontal, 16)
            } else {
                ValueSlider(
                    title: String(localized: "Reading line"),
                    valueText: settings.guidePosition.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
                    value: $settings.guidePosition,
                    range: PrompterSettings.guideRange, step: 0.01,
                    ends: (String(localized: "Top"), String(localized: "Bottom"))
                )
                .padding(.horizontal, 16)
                row(String(localized: "Background color")) {
                    HStack(spacing: 0) {
                        ForEach(StudioBackground.allCases) { option in
                            SwatchButton(color: option.color, isSelected: settings.studioBackground == option, accessibilityName: option.label) {
                                settings.studioBackground = option
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
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.ink.opacity(0.5))
                    // Forward points left in right to left, so it turns the other way to point down.
                    .rotationEffect(.degrees(showsAdvanced ? (layoutDirection == .rightToLeft ? -90 : 90) : 0))
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
        fontPicker
        GroupedCard(background: Palette.surface2, radius: 22) {
            ValueSlider(
                title: String(localized: "Line spacing"),
                valueText: settings.lineSpacing.formatted(.number.precision(.fractionLength(2)).locale(.interface)),
                value: $settings.lineSpacing,
                range: PrompterSettings.lineSpacingRange, step: 0.05,
                identifier: "display.lineSpacing"
            )
            .padding(.horizontal, 16)
            ValueSlider(
                title: String(localized: "Side margins"),
                valueText: String(localized: "\(Int(settings.margin)) pt"),
                value: $settings.margin,
                range: PrompterSettings.marginRange, step: 2
            )
            .padding(.horizontal, 16)
            row(String(localized: "Alignment")) {
                Picker("Alignment", selection: $settings.alignment) {
                    ForEach(PrompterAlignment.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            row(String(localized: "Text color")) {
                HStack(spacing: 0) {
                    ForEach(PrompterTextColor.allCases) { option in
                        SwatchButton(color: option.color, isSelected: settings.textColor == option, accessibilityName: option.label) {
                            settings.textColor = option
                        }
                    }
                }
            }
        }
        if showsCoreControls {
            GroupedCard(background: Palette.surface2, radius: 22) {
                SettingToggleRow(title: String(localized: "Show reading line"), isOn: $settings.showsGuide)
                SettingToggleRow(
                    title: String(localized: "Mirror text"), detail: String(localized: "For beam-splitter glass rigs"),
                    isOn: $settings.isMirrored
                )
            }
        }
    }

    private var fontPicker: some View {
        HStack(spacing: 8) {
            ForEach(PrompterFont.allCases) { font in
                Button {
                    settings.font = font
                } label: {
                    SelectableCard(isSelected: settings.font == font, radius: 14) {
                        VStack(spacing: 4) {
                            Text("Aa").font(font.font(size: 22))
                            Text(font.label).font(.caption2).foregroundStyle(Palette.ink2)
                        }
                        .frame(height: 66)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(font.label))
                .accessibilityIdentifier("display.font.\(font.rawValue)")
                .accessibilityAddTraits(settings.font == font ? .isSelected : [])
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
}
