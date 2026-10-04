//
//  PrompterOrbControls.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Prompter, v27: the reading controls as orbs. Speed, text size, the reading line and the margins in one
/// card; "Follow my voice" and the countdown in another. The preview above them changes as an orb moves.
struct PrompterOrbControls: View {
    @Bindable var viewModel: CreatorSetupViewModel

    var body: some View {
        VStack(spacing: 14) {
            GroupedCard(dividerInset: 0) {
                VStack(alignment: .leading, spacing: 22) {
                    OrbSlider(
                        value: $viewModel.speed, range: PrompterSettings.speedRange, defaultValue: ReadTime.naturalSpeed,
                        label: String(localized: "Speed"), valueText: String(localized: "\(viewModel.wordsPerMinute) wpm"),
                        spokenValue: String(localized: "\(viewModel.wordsPerMinute) words a minute"),
                        systemIcon: .speed, minCaption: String(localized: "Slow"), maxCaption: String(localized: "Fast"),
                        accessibilityIdentifier: "creatorSetup.speed"
                    )
                    Text("Used when Cue isn’t following your voice.")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkHint)
                        .padding(.top, -14)
                    OrbSlider(
                        value: $viewModel.textSizeStep, range: 0...3, step: 1, defaultValue: 1,
                        label: String(localized: "Text size"), valueText: viewModel.textSizeLabel,
                        systemIcon: .textSize, accessibilityIdentifier: "creatorSetup.textSize"
                    )
                    .id(PrompterSettingsSection.text)
                    OrbSlider(
                        value: $viewModel.readingLineStep, range: 0...2, step: 1, defaultValue: 0,
                        label: String(localized: "Reading line"), valueText: ReadingLinePreset(rawValue: Int(viewModel.readingLineStep))?.label
                            ?? String(localized: "Custom"),
                        systemIcon: .readingLine, minCaption: String(localized: "Camera"), maxCaption: String(localized: "Middle"),
                        accessibilityIdentifier: "creatorSetup.readingLinePreset"
                    )
                    OrbSlider(
                        value: $viewModel.marginStep, range: 0...2, step: 1, defaultValue: 1,
                        label: String(localized: "Margins"), valueText: MarginPreset(rawValue: Int(viewModel.marginStep))?.label ?? "",
                        systemIcon: .margins, accessibilityIdentifier: "creatorSetup.margins"
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
                OrbSlider(
                    value: $viewModel.countdownStep, range: 0...Double(Countdown.allCases.count - 1), step: 1, defaultValue: 1,
                    style: .row, label: String(localized: "Countdown"), valueText: Countdown.allCases[Int(viewModel.countdownStep)].label,
                    systemIcon: .countdown, accessibilityIdentifier: "creatorSetup.countdown"
                )
                .padding(.horizontal, 18)
                .frame(minHeight: 56)
            }
        }
    }
}
