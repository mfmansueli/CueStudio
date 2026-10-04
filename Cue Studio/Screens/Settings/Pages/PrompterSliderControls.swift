//
//  PrompterSliderControls.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Prompter: the reading controls as sliders (ranges from `CueSliderSpec`). Speed, text size, the reading line
/// and the margins in one card; "Follow my voice" and the countdown in another. The preview above them changes as a
/// thumb moves.
struct PrompterSliderControls: View {
    @Bindable var viewModel: CreatorSetupViewModel

    var body: some View {
        VStack(spacing: Metrics.blockGap) {
            GroupedCard(dividerInset: 0) {
                VStack(alignment: .leading, spacing: 22) {
                    CueSlider(
                        value: $viewModel.wordsPerMinuteValue, range: CueSliderSpec.speed.range, step: CueSliderSpec.speed.step,
                        defaultValue: CueSliderSpec.speed.defaultValue,
                        label: String(localized: "Speed"), valueText: String(localized: "\(viewModel.wordsPerMinute) wpm"),
                        spokenValue: String(localized: "\(viewModel.wordsPerMinute) words a minute"),
                        systemIcon: .speed, minCaption: String(localized: "80 wpm"), maxCaption: String(localized: "220 wpm"),
                        accessibilityIdentifier: "creatorSetup.speed"
                    )
                    Text("Used when Cue isn’t following your voice.")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkHint)
                        .padding(.top, -14)
                    CueSlider(
                        value: $viewModel.textSizeStep, range: CueSliderSpec.textSize.range, step: CueSliderSpec.textSize.step,
                        defaultValue: CueSliderSpec.textSize.defaultValue,
                        label: String(localized: "Text size"), valueText: viewModel.textSizeLabel,
                        systemIcon: .textSize, minCaption: String(localized: "Small"), maxCaption: String(localized: "Extra large"),
                        accessibilityIdentifier: "creatorSetup.textSize"
                    )
                    .id(PrompterSettingsSection.text)
                    CueSlider(
                        value: $viewModel.readingLinePercent, range: CueSliderSpec.readingLine.range,
                        step: CueSliderSpec.readingLine.step, defaultValue: CueSliderSpec.readingLine.defaultValue,
                        label: String(localized: "Reading line"), valueText: viewModel.readingLineLabel,
                        systemIcon: .readingLine, minCaption: String(localized: "10% · camera"), maxCaption: String(localized: "50% · middle"),
                        accessibilityIdentifier: "creatorSetup.readingLinePreset"
                    )
                    CueSlider(
                        value: $viewModel.marginPoints, range: CueSliderSpec.margins.range, step: CueSliderSpec.margins.step,
                        defaultValue: CueSliderSpec.margins.defaultValue,
                        label: String(localized: "Margins"), valueText: String(localized: "\(Int(viewModel.marginPoints)) pt"),
                        systemIcon: .margins, minCaption: String(localized: "8 pt"), maxCaption: String(localized: "40 pt"),
                        accessibilityIdentifier: "creatorSetup.margins"
                    )
                }
                .padding(18)
            }
            GroupedCard(dividerInset: 18) {
                HStack(spacing: 12) {
                    CueIconView(.followsVoice, size: 22).foregroundStyle(Palette.ink2)
                    Text("Follow my voice").font(.body).foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Toggle("Follow my voice", isOn: $viewModel.followsVoice)
                        .labelsHidden()
                        .tint(Palette.success)
                        .accessibilityIdentifier("creatorSetup.followsVoice")
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 56)
                CueSlider(
                    value: $viewModel.countdownStep, range: CueSliderSpec.countdown.range, step: CueSliderSpec.countdown.step,
                    defaultValue: CueSliderSpec.countdown.defaultValue, style: .row, label: String(localized: "Countdown"),
                    valueText: Countdown.allCases[Int(viewModel.countdownStep)].label, systemIcon: .countdown, accessibilityIdentifier: "creatorSetup.countdown"
                )
                .padding(.horizontal, 18)
                .frame(minHeight: 56)
            }
        }
    }
}
