//
//  AaSafeZoneSection.swift
//  Cue Studio
//

import SwiftUI

/// Aa › Window's safe zone: the recording's network's zone, or Custom with the creator's own margins (0 to 40% of each edge). On a frame
/// no network was measured on (1:1) Custom is the zone, so only its margins show. Whether the zone shows at all is in the Camera sheet and
/// Settings › Prompter › Safe zone.
struct AaSafeZoneSection: View {
    /// The network's zone on this frame; nil when only Custom fits.
    let networkZone: SafeZoneChoice?

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        @Bindable var session = session
        let isCustom = networkZone == nil || session.safeZonePick == .custom
        Section {
            if let networkZone {
                Picker(String(localized: "Safe zone"), selection: pick(networkZone)) {
                    Text(networkZone.label).tag(networkZone)
                    Text(SafeZoneChoice.custom.label).tag(SafeZoneChoice.custom)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("display.safeZonePicker")
                .frame(minHeight: Metrics.listRowContent)
                .cardRowBackground(position: isCustom ? .first : .only)
            }
            if isCustom {
                let first: CardRowPosition = networkZone == nil ? .first : .middle
                marginRow("top", String(localized: "Top"), \.top, SafeZoneMargins.topRange, first, $session.prompter.customSafeZone)
                marginRow("bottom", String(localized: "Bottom"), \.bottom, SafeZoneMargins.bottomRange, .middle, $session.prompter.customSafeZone)
                marginRow("left", String(localized: "Left"), \.left, SafeZoneMargins.leftRange, .middle, $session.prompter.customSafeZone)
                marginRow("right", String(localized: "Right"), \.right, SafeZoneMargins.rightRange, .last, $session.prompter.customSafeZone)
            }
        } header: {
            CueSectionHeader("Safe zone")
        } footer: {
            Text("A guide, not a guarantee · Never recorded")
        }
    }

    /// The network's zone or Custom; choosing the network follows it again.
    private func pick(_ networkZone: SafeZoneChoice) -> Binding<SafeZoneChoice> {
        Binding(
            get: { session.safeZonePick == .custom ? .custom : networkZone },
            set: { session.safeZonePick = $0 == .custom ? .custom : nil }
        )
    }

    /// `edge` names the slider for tests in every language ("settings.safeZoneMargin.top").
    private func marginRow(
        _ edge: String, _ title: String, _ keyPath: WritableKeyPath<SafeZoneMargins, Double>, _ range: ClosedRange<Double>, _ position: CardRowPosition,
        _ margins: Binding<SafeZoneMargins>
    ) -> some View {
        let value = margins[dynamicMember: keyPath]
        return SettingsSliderRow(
            title: title, valueText: "\(Int(value.wrappedValue.rounded()))%", valueSamples: ["\(Int(range.upperBound))%"], value: value,
            range: range, step: 1,
            identifier: "settings.safeZoneMargin.\(edge)"
        )
        .cardRowBackground(position: position)
    }
}
