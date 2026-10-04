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
                    .foregroundStyle(Palette.accText)
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityIdentifier("display.resetLayoutButton")
            }
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
            lineAndWindow
            SectionHeading(text: String(localized: "Social safe zone"))
                .padding(EdgeInsets(top: 6, leading: 4, bottom: 0, trailing: 4))
            safeZone
            Text("A guide, not a guarantee · Never recorded")
                .font(.caption)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 6)
        }
    }

    // MARK: - Line and window

    private var lineAndWindow: some View {
        @Bindable var session = session
        return GroupedCard(background: Palette.surface2, radius: 22) {
            readingLineRow
            DisplayLayoutControls.window(settings: $session.prompter)
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
                DisplayLayoutControls.safeZoneMargins(settings: $session.prompter)
            }
            SettingToggleRow(
                title: String(localized: "Show safe zone"),
                detail: current?.detail ?? String(localized: "Not needed for horizontal video"),
                isOn: $session.camera.showsSafeZones,
                minHeight: 56
            )
            .disabled(current == nil)
            .accessibilityIdentifier("display.showSafeZoneToggle")
        }
        .animation(.smooth(duration: 0.25), value: current)
    }
}
