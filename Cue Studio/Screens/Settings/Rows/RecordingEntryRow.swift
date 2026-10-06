//
//  RecordingEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The rows of Settings › Recording: the camera it starts with, the quality, the default format, the microphone and what happens
/// while recording.
struct RecordingEntryRow: View {
    let entry: SettingsEntry
    @Binding var camera: CameraSettings

    var body: some View {
        content
            .accessibilityIdentifier("settings.\(entry.rawValue)")
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .startsWith:
            SettingsSegmentedRow(
                title: entry.title, selection: startsWithFront, options: [true, false],
                label: { $0 ? String(localized: "Front") : String(localized: "Back") },
                identifier: "settings.startsWithPicker"
            )
        case .resolution:
            Picker(entry.title, selection: $camera.resolution) {
                ForEach(VideoResolution.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Palette.ink2)
            .frame(minHeight: Metrics.listRowContent)
        case .frameRate:
            Picker(entry.title, selection: $camera.frameRate) {
                ForEach(FrameRate.allCases) { Text(String(localized: "\($0.rawValue) fps")).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Palette.ink2)
            .frame(minHeight: Metrics.listRowContent)
        case .defaultFormat:
            formatTiles
        case .microphone:
            NavigationLink(value: SettingsRoute.microphone) {
                SettingsValueLabel(title: entry.title, value: microphoneValue)
            }
        case .countdown, .countdownBeforePlay:
            Picker(entry.title, selection: $camera.countdown) {
                ForEach(Countdown.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Palette.ink2)
            .frame(minHeight: Metrics.listRowContent)
        case .grid:
            SettingsListToggle(title: entry.title, detail: entry.detail, isOn: $camera.showsGrid)
        default:
            EmptyView()
        }
    }

    private var startsWithFront: Binding<Bool> {
        Binding(
            get: { camera.lens.isFront },
            set: { camera.lens = $0 ? .front : .wide }
        )
    }

    private var microphoneValue: String {
        MicrophoneChoice(id: camera.microphoneID, name: camera.microphoneName).label
    }

    /// 9:16 · 4:5 · 1:1 · 16:9, each drawn in proportion; the chosen one has the yellow ring.
    private var formatTiles: some View {
        HStack(spacing: 8) {
            ForEach(AspectRatio.allCases) { aspect in
                let isSelected = camera.aspect == aspect
                Button { camera.aspect = aspect } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Palette.ink, lineWidth: 1.6)
                            .frame(width: 22 * min(1, aspect.widthOverHeight), height: 22 * min(1, 1 / aspect.widthOverHeight))
                            .frame(height: 24)
                        Text(aspect.label).font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(isSelected ? Palette.accTile : Palette.surface2.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isSelected ? Palette.acc : .clear, lineWidth: 2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(aspect.label))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("settings.format.\(aspect.rawValue)")
            }
        }
        .padding(.vertical, 4)
    }
}
