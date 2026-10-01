//
//  PanelStepper.swift
//  Cue Studio
//

import SwiftUI

/// A value with − and + ("Pauses longer than 0.7s", "Starts 00:05.2").
struct PanelStepper: View {
    let label: String
    let value: String
    var canDecrease = true
    var canIncrease = true
    let identifier: String
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack {
            Text(label).font(.system(.subheadline, weight: .semibold))
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                button("minus", label: Text("Less"), enabled: canDecrease, id: "\(identifier).minus", action: onDecrease)
                Text(value)
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                    .frame(minWidth: 56)
                    .accessibilityIdentifier("\(identifier).value")
                button("plus", label: Text("More"), enabled: canIncrease, id: "\(identifier).plus", action: onIncrease)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func button(_ symbol: String, label: Text, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(enabled ? 1 : 0.35))
                .frame(width: 36, height: 32)
                .background(Palette.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
