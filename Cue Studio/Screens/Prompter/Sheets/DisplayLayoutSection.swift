//
//  DisplayLayoutSection.swift
//  Cue Studio
//

import SwiftUI

/// Display › Layout, in Selfie mode: where the reading line sits, the text window's size, the
/// social safe zone and hiding the controls while recording, with a way back to the recommended
/// layout.
struct DisplayLayoutSection: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(text: String(localized: "Layout"))
                Button("Reset to Recommended") { viewModel.resetLayout() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.acc)
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityIdentifier("display.resetLayoutButton")
            }
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
            lineAndWindow
            SectionHeading(text: String(localized: "Social safe zone"))
                .padding(EdgeInsets(top: 6, leading: 4, bottom: 0, trailing: 4))
            safeZone
            Text("Safe zones are a visual guide based on each app’s current layout — platforms change their UI, so they’re not a guarantee. Nothing on this screen appears in your video: Cue records the full frame only.")
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .padding(.horizontal, 6)
        }
    }

    // MARK: - Line and window

    private var lineAndWindow: some View {
        @Bindable var session = session
        return GroupedCard(background: Palette.surface2, radius: 22) {
            readingLineRow
            ValueSlider(
                title: String(localized: "Text window height"),
                valueText: String(localized: "\(Int(session.prompter.textWindowHeight)) pt"),
                value: $session.prompter.textWindowHeight,
                range: PrompterSettings.textWindowHeightRange, step: 10,
                identifier: "display.textWindowHeight"
            )
            .padding(.horizontal, 16)
            ValueSlider(
                title: String(localized: "Text window width"),
                valueText: session.prompter.readingWidth.formatted(.percent.precision(.fractionLength(0))),
                value: $session.prompter.readingWidth,
                range: PrompterSettings.readingWidthRange, step: 0.01,
                ends: (String(localized: "Narrow · less eye movement"), String(localized: "Wide")),
                identifier: "display.readingWidth"
            )
            .padding(.horizontal, 16)
        }
    }

    private var readingLineRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reading line")
                Text(readingLineSummary)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("display.readingLineSummary")
            }
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                Button { viewModel.nudgeReadingLine(by: -ReadingLayout.nudge) } label: {
                    Image(systemName: "chevron.up").frame(width: 44, height: 36)
                }
                .accessibilityLabel(Text("Move the reading line up"))
                .accessibilityIdentifier("display.readingLineUp")
                Rectangle()
                    .fill(Palette.separator)
                    .frame(width: 0.5, height: 20)
                Button { viewModel.nudgeReadingLine(by: ReadingLayout.nudge) } label: {
                    Image(systemName: "chevron.down").frame(width: 44, height: 36)
                }
                .accessibilityLabel(Text("Move the reading line down"))
                .accessibilityIdentifier("display.readingLineDown")
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Palette.ink)
            .buttonStyle(.plain)
            .background(Palette.fill, in: Capsule())
        }
        .frame(minHeight: 62)
        .padding(.horizontal, 16)
    }

    /// "118 pt below the camera · recommended".
    private var readingLineSummary: String {
        let layout = viewModel.readingLayout
        let points = Int(layout.lineOffset)
        guard layout.isRecommended else {
            return String(localized: "\(points) pt below the camera · drag the handle on screen")
        }
        return session.camera.lens.isFront
            ? String(localized: "\(points) pt below the camera · recommended")
            : String(localized: "Centered for the rear camera · recommended")
    }

    // MARK: - Safe zone

    private var safeZone: some View {
        @Bindable var session = session
        let options = viewModel.safeZoneOptions
        let current = viewModel.safeZone
        return GroupedCard(background: Palette.surface2, radius: 22) {
            if !options.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button { viewModel.pickSafeZone(option) } label: {
                            FilterChip(label: option.label, isSelected: option == current)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(option == current ? .isSelected : [])
                        .accessibilityIdentifier("display.safeZone.\(option.key)")
                    }
                }
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            if current == .custom {
                customMargins
            }
            SettingToggleRow(
                title: String(localized: "Show safe zone"),
                detail: current?.detail ?? String(localized: "Not needed for horizontal video"),
                isOn: $session.camera.showsSafeZones,
                minHeight: 56
            )
            .disabled(current == nil)
            .accessibilityIdentifier("display.showSafeZoneToggle")
            SettingToggleRow(
                title: String(localized: "Hide controls while recording"),
                detail: String(localized: "Keeps only the text, line and stop"),
                isOn: $session.prompter.hidesControlsWhileRecording,
                minHeight: 56
            )
            .accessibilityIdentifier("display.hideControlsToggle")
        }
        .animation(.smooth(duration: 0.25), value: current)
    }

    @ViewBuilder
    private var customMargins: some View {
        @Bindable var session = session
        margin(String(localized: "Top risk"), value: $session.prompter.customSafeZone.top, range: SafeZoneMargins.topRange)
        margin(String(localized: "Bottom risk"), value: $session.prompter.customSafeZone.bottom, range: SafeZoneMargins.bottomRange)
        margin(String(localized: "Left risk"), value: $session.prompter.customSafeZone.left, range: SafeZoneMargins.leftRange)
        margin(String(localized: "Right risk"), value: $session.prompter.customSafeZone.right, range: SafeZoneMargins.rightRange)
    }

    private func margin(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        ValueSlider(
            title: title,
            valueText: "\(Int(value.wrappedValue))%",
            value: value,
            range: range
        )
        .padding(.horizontal, 16)
    }
}
