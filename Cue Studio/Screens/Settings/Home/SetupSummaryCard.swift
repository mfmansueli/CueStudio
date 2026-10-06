//
//  SetupSummaryCard.swift
//  Cue Studio
//

import SwiftUI

/// "YOUR SETUP": the default format drawn as a phone, and the four values every recording starts from (Camera, Quality, Mic, Text).
/// Each value opens the page that sets it.
struct SetupSummaryCard: View {
    let camera: CameraSettings
    let prompter: PrompterSettings
    let onOpen: (SettingsRoute) -> Void

    private var setup: CreatorSetup { CreatorSetup(camera: camera, prompter: prompter) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        HStack(alignment: .center, spacing: 14) {
            phone
            VStack(alignment: .leading, spacing: 8) {
                Text("Your setup")
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Palette.accText)
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        tile(String(localized: "Camera"), setup.label(for: .camera), "camera", .recording)
                        tile(String(localized: "Quality"), "\(camera.resolution.label) · \(camera.frameRate.rawValue)", "quality", .recording)
                    }
                    GridRow {
                        tile(String(localized: "Mic"), setup.microphone.label, "mic", .microphone)
                        tile(String(localized: "Text"), textValue, "text", .prompter)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .nightAurora(in: shape)
        .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
        .clipShape(shape)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.setupCard")
    }

    private var textValue: String {
        guard let preset = PrompterTextSize(points: prompter.size) else { return String(localized: "\(Int(prompter.size.rounded())) pt") }
        return preset.label
    }

    /// The default format in proportion, as a phone with a few lines of script, and its name.
    private var phone: some View {
        let ratio = CGFloat(camera.aspect.widthOverHeight)
        let height: CGFloat = 110
        let width = min(70, height * ratio)
        let frameHeight = min(height, 70 / max(ratio, 0.01))
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return ZStack {
            shape
                .fill(Palette.previewWell)
                .overlay(shape.strokeBorder(Palette.ink3, lineWidth: 1.5))
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2).fill(Palette.ink).frame(height: 3)
                RoundedRectangle(cornerRadius: 2).fill(Palette.acc).frame(height: 3)
                RoundedRectangle(cornerRadius: 2).fill(Palette.ink3).frame(width: width * 0.55, height: 3)
            }
            .padding(10)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 6)
            Text(camera.aspect.label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.ink2)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 6)
        }
        .frame(width: width, height: frameHeight)
        .frame(width: 76, height: height)
        .accessibilityHidden(true)
    }

    private func tile(_ title: String, _ value: String, _ id: String, _ route: SettingsRoute) -> some View {
        Button { onOpen(route) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 10.5)).foregroundStyle(Palette.ink2)
                Text(value)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .background(Palette.heroChip, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.setup.\(id)")
    }
}
