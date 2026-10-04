//
//  TeleprompterSetupSection.swift
//  Cue Studio
//

import SwiftUI

/// Creator Setup › Teleprompter: reading defaults and an entry to the shared Display editor.
/// These are the defaults; the prompter can still change any of them for one take.
struct TeleprompterSetupSection: View {
    @Bindable var viewModel: CreatorSetupViewModel
    @State private var showsDisplay = false

    var body: some View {
        GroupedCard {
            readingLineRow
            SetupRow(title: String(localized: "Show reading line"), stacksControl: false) {
                Toggle("Show reading line", isOn: $viewModel.showsReadingLine)
                    .labelsHidden()
                    .tint(Palette.successText)
            }
            SetupRow(title: String(localized: "Mirror text"), detail: String(localized: "For beam-splitter glass rigs"), stacksControl: false) {
                Toggle("Mirror text", isOn: $viewModel.isMirrored)
                    .labelsHidden()
                    .tint(Palette.successText)
                    .accessibilityIdentifier("creatorSetup.mirrorToggle")
            }
            SetupRow(
                title: String(localized: "Safe zones"),
                detail: String(localized: "Shows where each app's buttons and captions cover the frame"),
                stacksControl: false,
                anchor: .safeZones
            ) {
                Toggle("Safe zones", isOn: $viewModel.showsSafeZones)
                    .labelsHidden()
                    .tint(Palette.successText)
                    .accessibilityIdentifier("creatorSetup.safeZonesToggle")
            }
            SetupRow(
                title: String(localized: "Display"), detail: String(localized: "Font, spacing, margins, alignment, color"),
                stacksControl: false, anchor: .window
            ) {
                Button { showsDisplay = true } label: {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Display"))
                .accessibilityIdentifier("creatorSetup.displayButton")
            }
        }
        .sheet(isPresented: $showsDisplay) {
            CreatorDisplaySettingsSheet(viewModel: viewModel)
        }
    }

    private var readingLineRow: some View {
        SetupRow(title: String(localized: "Fine-tune the reading line"), detail: viewModel.readingLineSummary, stacksControl: false, anchor: .line) {
            HStack(spacing: 8) {
                if !viewModel.isReadingLineRecommended {
                    Button("Reset") { viewModel.resetReadingLine() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accText)
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
