//
//  SpeedCurvePanel.swift
//  Cue Studio
//

import SwiftUI

/// Speed › Curve: None, the ready-made curves (each drawn as it plays) and Custom in a row, and the picked clip's curve to
/// shape by its points.
struct SpeedCurvePanel: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let curve = viewModel.targetCurve
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                card(label: String(localized: "None"), curve: nil, isOn: curve == nil, key: "none") { viewModel.setSpeedCurve(nil) }
                ForEach(SpeedCurvePreset.allCases) { preset in
                    card(label: preset.label, curve: preset.curve, isOn: curve?.preset == preset, key: preset.rawValue) {
                        viewModel.setSpeedCurve(preset)
                    }
                }
                card(
                    label: String(localized: "Custom"), curve: nil, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                    isOn: curve != nil && curve?.preset == nil, key: "custom"
                ) { viewModel.shapeOwnCurve() }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
        if let curve {
            SpeedCurveEditor(viewModel: viewModel, curve: curve)
            PanelNote(text: String(localized: "Drag a point up to speed up, down to slow down."))
        }
    }

    private func card(
        label: String, curve: SpeedCurve?, symbol: String = "circle.slash", isOn: Bool, key: String, action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let curve {
                        SpeedCurveGlyph(curve: curve, color: isOn ? Palette.accText : Palette.ink)
                    } else {
                        Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                    }
                }
                .frame(width: 56, height: 28)
                Text(label)
                    .font(.system(.footnote, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(isOn ? Palette.accText : Palette.ink)
            .padding(.horizontal, 10)
            .frame(minWidth: 76, minHeight: 68)
            .background(isOn ? Palette.Editor.accTile : Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.speed.curve.\(key)")
    }
}
