//
//  PrompterEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The rows of Settings › Prompter: reading, text, the reading line, the text window, what is over the camera, Studio and the rigs.
struct PrompterEntryRow: View {
    let entry: SettingsEntry
    let bindings: SettingsBindings

    @Environment(ToastService.self) private var toast

    private var settings: Binding<PrompterSettings> { bindings.prompter }

    var body: some View {
        content
            .accessibilityIdentifier("settings.\(entry.rawValue)")
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .followVoice:
            SettingsListToggle(title: entry.title, detail: entry.detail, isOn: followsVoice)
        case .speed:
            SettingsSliderRow(
                title: entry.title, valueText: String(localized: "\(wordsPerMinute) wpm"), detail: entry.detail, value: speed,
                range: 80...220, step: PrompterSettings.wordsPerMinuteStep,
                minLabel: "80", maxLabel: String(localized: "220 wpm"), identifier: "settings.speedSlider"
            )
        case .aiCoach:
            SettingsListToggle(title: entry.title, detail: entry.detail, isOn: settings.showsCues)
        case .textSize:
            SettingsSegmentedRow(
                title: entry.title, selection: textSize, options: PrompterTextSize.allCases, label: \.shortLabel,
                identifier: "settings.textSizePicker"
            )
        case .font:
            NavigationLink(value: SettingsRoute.font) {
                SettingsValueLabel(title: entry.title, value: settings.wrappedValue.font.label)
            }
        case .lineSpacing:
            SettingsSliderRow(
                title: entry.title,
                valueText: settings.wrappedValue.lineSpacing.formatted(.number.precision(.fractionLength(2)).locale(.interface)),
                value: settings.lineSpacing, range: PrompterSettings.lineSpacingRange, step: 0.05,
                minLabel: String(localized: "Tight"), maxLabel: String(localized: "Airy"), identifier: "settings.lineSpacingSlider"
            )
        case .alignment:
            SettingsSegmentedRow(
                title: entry.title, selection: settings.alignment, options: PrompterAlignment.allCases, label: \.label,
                identifier: "settings.alignmentPicker"
            )
        case .textColor:
            Picker(entry.title, selection: settings.textColor) {
                ForEach(PrompterTextColor.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Palette.ink2)
            .frame(minHeight: Metrics.listRowContent)
            .accessibilityIdentifier("settings.textColorPicker")
        case .showReadingLine:
            SettingsListToggle(title: entry.title, isOn: settings.showsGuide)
        case .readingLinePosition:
            SettingsSliderRow(
                title: entry.title, valueText: "\(Int(readingLinePercent.wrappedValue.rounded()))%", value: readingLinePercent,
                range: 10...50, step: 1, minLabel: String(localized: "Near camera"), maxLabel: String(localized: "Middle"),
                identifier: "settings.readingLineSlider"
            )
        case .resetReadingLine:
            Button(entry.title) { resetToRecommended() }
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.listRowContent)
        case .windowHeight:
            SettingsSliderRow(
                title: entry.title, valueText: String(localized: "\(Int(settings.wrappedValue.boxHeight)) pt"), value: settings.boxHeight,
                range: PrompterSettings.textWindowHeightRange, step: 10,
                minLabel: "\(Int(PrompterSettings.textWindowHeightRange.lowerBound))",
                maxLabel: String(localized: "\(Int(PrompterSettings.textWindowHeightRange.upperBound)) pt"), identifier: "settings.windowHeightSlider"
            )
        case .windowWidth:
            SettingsSliderRow(
                title: entry.title, valueText: "\(Int((settings.wrappedValue.boxWidth * 100).rounded()))%", detail: entry.detail,
                value: windowWidthPercent, range: (PrompterSettings.readingWidthRange.lowerBound * 100)...(PrompterSettings.readingWidthRange.upperBound * 100),
                step: 1, minLabel: String(localized: "Narrow"), maxLabel: String(localized: "Wide"), identifier: "settings.windowWidthSlider"
            )
        case .sideMargins:
            SettingsSliderRow(
                title: entry.title, valueText: String(localized: "\(Int(settings.wrappedValue.margin)) pt"), value: settings.margin,
                range: PrompterSettings.marginRange, step: 2, minLabel: "\(Int(PrompterSettings.marginRange.lowerBound))",
                maxLabel: String(localized: "\(Int(PrompterSettings.marginRange.upperBound)) pt"), identifier: "settings.sideMarginsSlider"
            )
        case .backgroundOpacity:
            SettingsSliderRow(
                title: entry.title, valueText: "\(Int((settings.wrappedValue.backgroundOpacity * 100).rounded()))%",
                value: settings.backgroundOpacity, range: PrompterSettings.backgroundOpacityRange, step: 0.05,
                minLabel: "0%", maxLabel: "100%", identifier: "settings.backgroundOpacitySlider"
            )
        case .cameraBlur:
            SettingsSliderRow(
                title: entry.title, valueText: blurPercent.wrappedValue == 0 ? String(localized: "Off") : "\(Int(blurPercent.wrappedValue))%",
                value: blurPercent, range: 0...100, step: 5, minLabel: String(localized: "Off"), maxLabel: String(localized: "Strong"),
                identifier: "settings.cameraBlurSlider"
            )
        case .socialSafeZone:
            NavigationLink(value: SettingsRoute.safeZone) {
                SettingsValueLabel(
                    title: entry.title,
                    value: bindings.camera.wrappedValue.showsSafeZones
                        ? SafeZoneChoice.saved(key: settings.wrappedValue.safeZoneKey).label : String(localized: "Off")
                )
            }
        case .studioBackground:
            Picker(entry.title, selection: settings.studioBackground) {
                ForEach([StudioBackground.navy, .black, .graphite]) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Palette.ink2)
            .frame(minHeight: Metrics.listRowContent)
            .accessibilityIdentifier("settings.studioBackgroundPicker")
        case .mirrorText:
            SettingsListToggle(title: entry.title, detail: entry.detail, isOn: settings.isMirrored)
        case .flipVertically:
            SettingsListToggle(title: entry.title, detail: entry.detail, isOn: settings.isFlippedVertically)
        default:
            EmptyView()
        }
    }

    // MARK: - Bindings

    private var followsVoice: Binding<Bool> {
        Binding(
            get: { settings.wrappedValue.scrollMode == .voice },
            set: { settings.wrappedValue.scrollMode = $0 ? .voice : .steady }
        )
    }

    private var wordsPerMinute: Int {
        Int(PrompterSettings.wordsPerMinute(forSpeed: settings.wrappedValue.speed).rounded())
    }

    /// 80–220 words a minute, in steps of 5; stored as a speed.
    private var speed: Binding<Double> {
        Binding(
            get: { PrompterSettings.wordsPerMinute(forSpeed: settings.wrappedValue.speed).rounded() },
            set: { settings.wrappedValue.speed = PrompterSettings.speed(forWordsPerMinute: $0) }
        )
    }

    private var textSize: Binding<PrompterTextSize> {
        Binding(
            get: { PrompterTextSize.nearest(to: settings.wrappedValue.size) },
            set: { settings.wrappedValue.size = $0.points }
        )
    }

    /// Where the reading line sits as a percent of the screen's height: 10 by the camera, 50 in the middle.
    private var readingLinePercent: Binding<Double> {
        Binding(
            get: { settings.wrappedValue.readingLine(on: bindings.screenScale) * 100 },
            set: { settings.wrappedValue.setReadingLine($0 / 100, on: bindings.screenScale) }
        )
    }

    /// The camera blur as the percent the page shows (0 is Off, 100 the strongest blur the camera takes).
    private var blurPercent: Binding<Double> {
        let top = PrompterSettings.cameraBlurRange.upperBound
        return Binding(
            get: { settings.wrappedValue.cameraBlur / top * 100 },
            set: { settings.wrappedValue.cameraBlur = $0 / 100 * top }
        )
    }

    /// "Reset to recommended": the line, the text window and the margins go back to where Cue puts them.
    private func resetToRecommended() {
        settings.wrappedValue.readingLineOffset = nil
        settings.wrappedValue.readingWidth = PrompterSettings.defaultReadingWidth
        settings.wrappedValue.textWindowHeight = PrompterSettings.defaultTextWindowHeight
        settings.wrappedValue.margin = PrompterSettings().margin
        toast.show(String(localized: "Back to recommended"))
    }

    private var windowWidthPercent: Binding<Double> {
        Binding(
            get: { settings.wrappedValue.boxWidth * 100 },
            set: { settings.wrappedValue.boxWidth = $0 / 100 }
        )
    }
}
