//
//  DisplaySettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Aa": how the prompter reads, with a live preview behind the sheet. In Selfie mode the layout
/// comes first (reading line, text window, safe zone); then quick settings, and the rest under
/// Advanced. Over the Selfie camera the sheet never covers the text window.
struct DisplaySettingsSheet: View {
    let viewModel: PrompterViewModel
    /// Tallest the sheet may grow in Selfie mode, so the text window above stays in sight.
    var maxHeight: CGFloat?

    @Environment(SessionSetupService.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var showsAdvanced = false

    /// The medium detent, as in the design.
    private static let compactHeight: CGFloat = 330

    private var mode: PrompterMode { viewModel.mode }

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if mode == .selfie {
                        DisplayLayoutSection(viewModel: viewModel)
                            .padding(.bottom, 6)
                    }
                    SectionHeading(text: String(localized: "Quick"))
                        .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
                    GroupedCard(background: Palette.surface2, radius: 22) {
                        SettingToggleRow(
                            title: String(localized: "AI Coach"),
                            detail: String(localized: "Performance cues like PAUSE or SMILE"),
                            isOn: $session.prompter.showsCues
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

    /// Selfie: text size, then how the window sits on the camera. Studio: text size, where the
    /// line sits in the text, and the background color.
    private var quickSliders: some View {
        @Bindable var session = session
        return GroupedCard(background: Palette.surface2, radius: 22) {
            ValueSlider(
                title: String(localized: "Text size"),
                valueText: "\(Int(session.prompter.size))",
                value: $session.prompter.size,
                range: PrompterSettings.sizeRange
            )
            .padding(.horizontal, 16)
            if mode == .selfie {
                ValueSlider(
                    title: String(localized: "Background opacity"),
                    valueText: session.prompter.backgroundOpacity.formatted(.percent.precision(.fractionLength(0))),
                    value: $session.prompter.backgroundOpacity,
                    range: PrompterSettings.backgroundOpacityRange, step: 0.05
                )
                .padding(.horizontal, 16)
                ValueSlider(
                    title: String(localized: "Camera blur"),
                    valueText: session.prompter.cameraBlurLabel,
                    value: $session.prompter.cameraBlur,
                    range: PrompterSettings.cameraBlurRange
                )
                .padding(.horizontal, 16)
            } else {
                ValueSlider(
                    title: String(localized: "Reading line"),
                    valueText: session.prompter.guidePosition.formatted(.percent.precision(.fractionLength(0))),
                    value: $session.prompter.guidePosition,
                    range: PrompterSettings.guideRange, step: 0.01,
                    ends: (String(localized: "Top"), String(localized: "Bottom"))
                )
                .padding(.horizontal, 16)
                row(String(localized: "Background color")) {
                    HStack(spacing: 0) {
                        ForEach(StudioBackground.allCases) { option in
                            SwatchButton(color: option.color, isSelected: session.prompter.studioBackground == option, accessibilityName: option.label) {
                                session.prompter.studioBackground = option
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
        @Bindable var session = session
        fontPicker
        GroupedCard(background: Palette.surface2, radius: 22) {
            ValueSlider(
                title: String(localized: "Line spacing"),
                valueText: session.prompter.lineSpacing.formatted(.number.precision(.fractionLength(2))),
                value: $session.prompter.lineSpacing,
                range: PrompterSettings.lineSpacingRange, step: 0.05
            )
            .padding(.horizontal, 16)
            ValueSlider(
                title: String(localized: "Side margins"),
                valueText: String(localized: "\(Int(session.prompter.margin)) pt"),
                value: $session.prompter.margin,
                range: PrompterSettings.marginRange, step: 2
            )
            .padding(.horizontal, 16)
            row(String(localized: "Alignment")) {
                Picker("Alignment", selection: $session.prompter.alignment) {
                    ForEach(PrompterAlignment.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            row(String(localized: "Text color")) {
                HStack(spacing: 0) {
                    ForEach(PrompterTextColor.allCases) { option in
                        SwatchButton(color: option.color, isSelected: session.prompter.textColor == option, accessibilityName: option.label) {
                            session.prompter.textColor = option
                        }
                    }
                }
            }
        }
        GroupedCard(background: Palette.surface2, radius: 22) {
            SettingToggleRow(title: String(localized: "Show reading line"), isOn: $session.prompter.showsGuide)
            SettingToggleRow(title: String(localized: "Mirror text"), detail: String(localized: "For beam-splitter glass rigs"), isOn: $session.prompter.isMirrored)
        }
    }

    private var fontPicker: some View {
        HStack(spacing: 8) {
            ForEach(PrompterFont.allCases) { font in
                Button {
                    session.prompter.font = font
                } label: {
                    SelectableCard(isSelected: session.prompter.font == font, radius: 14) {
                        VStack(spacing: 4) {
                            Text("Aa").font(font.font(size: 22))
                            Text(font.label).font(.caption2).foregroundStyle(Palette.ink2)
                        }
                        .frame(height: 66)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(font.label))
                .accessibilityAddTraits(session.prompter.font == font ? .isSelected : [])
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

#if DEBUG
#Preview {
    let viewModel = PrompterViewModel.preview()
    Color.black.sheet(isPresented: .constant(true)) {
        DisplaySettingsSheet(viewModel: viewModel)
    }
    .environment(viewModel.session)
    .previewEnvironment()
}
#endif
