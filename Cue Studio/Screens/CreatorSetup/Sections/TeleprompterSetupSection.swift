//
//  TeleprompterSetupSection.swift
//  Cue Studio
//

import SwiftUI

/// Creator Setup › Teleprompter: text size, default speed, reading line, mirror and safe zones.
/// These are the defaults; the prompter can still change any of them for one take.
struct TeleprompterSetupSection: View {
    @Bindable var viewModel: CreatorSetupViewModel

    var body: some View {
        GroupedCard {
            SetupRow(title: String(localized: "Text size")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        ForEach(PrompterTextSize.allCases) { size in
                            Button {
                                viewModel.setTextSize(size)
                            } label: {
                                FilterChip(label: size.label, isSelected: viewModel.textSizePreset == size)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(viewModel.textSizePreset == size ? .isSelected : [])
                            .accessibilityIdentifier("creatorSetup.textSize.\(size.rawValue)")
                        }
                    }
                    ValueSlider(
                        title: String(localized: "Size"),
                        valueText: String(localized: "\(Int(viewModel.textSize)) pt"),
                        value: $viewModel.textSize,
                        range: PrompterSettings.sizeRange,
                        identifier: "creatorSetup.textSizeSlider"
                    )
                }
            }
            SetupRow(title: String(localized: "Scroll speed"), detail: viewModel.speedDetail) {
                ValueSlider(
                    title: String(localized: "Default speed"),
                    valueText: viewModel.setup.label(for: .speed),
                    value: $viewModel.speed,
                    range: PrompterSettings.speedRange, step: 0.1,
                    identifier: "creatorSetup.speedSlider"
                )
            }
            readingLineRow
            SetupRow(title: String(localized: "Show reading line"), stacksControl: false) {
                Toggle("Show reading line", isOn: $viewModel.showsReadingLine)
                    .labelsHidden()
                    .tint(Palette.success)
            }
            SetupRow(title: String(localized: "Mirror text"), detail: String(localized: "For beam-splitter glass rigs"), stacksControl: false) {
                Toggle("Mirror text", isOn: $viewModel.isMirrored)
                    .labelsHidden()
                    .tint(Palette.success)
                    .accessibilityIdentifier("creatorSetup.mirrorToggle")
            }
            SetupRow(title: String(localized: "Safe zones"), detail: String(localized: "Shows where each app's buttons and captions cover the frame"), stacksControl: false) {
                Toggle("Safe zones", isOn: $viewModel.showsSafeZones)
                    .labelsHidden()
                    .tint(Palette.success)
                    .accessibilityIdentifier("creatorSetup.safeZonesToggle")
            }
        }
    }

    private var readingLineRow: some View {
        SetupRow(title: String(localized: "Reading line"), detail: viewModel.readingLineSummary, stacksControl: false) {
            HStack(spacing: 8) {
                if !viewModel.isReadingLineRecommended {
                    Button("Reset") { viewModel.resetReadingLine() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.acc)
                        .buttonStyle(.plain)
                        .frame(minHeight: Metrics.hitTarget)
                        .accessibilityLabel(Text("Reset the reading line"))
                }
                HStack(spacing: 0) {
                    Button { viewModel.nudgeReadingLine(by: -CreatorSetupViewModel.readingLineStep) } label: {
                        Image(systemName: "chevron.up").frame(width: 44, height: 36)
                    }
                    .accessibilityLabel(Text("Move the reading line up"))
                    .accessibilityIdentifier("creatorSetup.readingLineUp")
                    Rectangle()
                        .fill(Palette.separator)
                        .frame(width: 0.5, height: 20)
                    Button { viewModel.nudgeReadingLine(by: CreatorSetupViewModel.readingLineStep) } label: {
                        Image(systemName: "chevron.down").frame(width: 44, height: 36)
                    }
                    .accessibilityLabel(Text("Move the reading line down"))
                    .accessibilityIdentifier("creatorSetup.readingLineDown")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.ink)
                .buttonStyle(.plain)
                .background(Palette.fill, in: Capsule())
            }
        }
        .accessibilityIdentifier("creatorSetup.readingLine")
    }
}
