//
//  DisplayLayoutControls.swift
//  Cue Studio
//

import SwiftUI

/// Shared row builders preserve the GroupedCard separators in both editors.
enum DisplayLayoutControls {
    @ViewBuilder
    static func window(settings: Binding<PrompterSettings>) -> some View {
        ValueSlider(
            title: String(localized: "Text window height"),
            valueText: String(localized: "\(Int(settings.wrappedValue.textWindowHeight)) pt"),
            value: settings.textWindowHeight,
            range: PrompterSettings.textWindowHeightRange, step: 10,
            identifier: "display.textWindowHeight"
        )
        .padding(.horizontal, 16)
        ValueSlider(
            title: String(localized: "Text window width"),
            valueText: settings.wrappedValue.readingWidth.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
            value: settings.readingWidth,
            range: PrompterSettings.readingWidthRange, step: 0.01,
            ends: (String(localized: "Narrow · less eye movement"), String(localized: "Wide")),
            identifier: "display.readingWidth"
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    static func safeZoneMargins(settings: Binding<PrompterSettings>) -> some View {
        margin(String(localized: "Top risk"), value: settings.customSafeZone.top, range: SafeZoneMargins.topRange)
        margin(String(localized: "Bottom risk"), value: settings.customSafeZone.bottom, range: SafeZoneMargins.bottomRange)
        margin(String(localized: "Left risk"), value: settings.customSafeZone.left, range: SafeZoneMargins.leftRange)
        margin(String(localized: "Right risk"), value: settings.customSafeZone.right, range: SafeZoneMargins.rightRange)
    }

    private static func margin(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        ValueSlider(
            title: title,
            valueText: (value.wrappedValue / 100).formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
            value: value,
            range: range
        )
        .padding(.horizontal, 16)
    }
}
