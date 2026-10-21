//
//  ReadyToggle.swift
//  Cue Studio
//

import SwiftUI

/// "Ready to record": the switch that moves a script between draft and ready, and the only thing on the page that does (leaving never
/// does; recording moves it to recorded). Off, a quiet capsule with an empty ring. On, green with a ✓, and it lights up once as it turns
/// on (the view model plays two soft taps with it). Its name says what it does, so leaving the page is never mistaken for it, as "Done"
/// was. Reduce Motion: no glow.
struct ReadyToggle: View {
    let isOn: Bool
    /// An empty page has nothing to make ready.
    var isEnabled = true
    let onChange: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The light it gives once as it turns on, 1 → 0.
    @State private var glow: Double = 0

    var body: some View {
        Button { onChange(!isOn) } label: {
            HStack(spacing: 7) {
                mark
                Text("Ready to record")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isOn ? Palette.successText : Palette.ink)
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: 32)
            .background(isOn ? Palette.Page.readyFill : Palette.fill, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Palette.Page.readyRim : .clear, lineWidth: 0.5))
            .shadow(color: Palette.success.opacity(0.6 * glow), radius: 16)
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: isOn)
        .onChange(of: isOn) { _, on in
            guard on, !reduceMotion else { return }
            glow = 1
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) { glow = 0 }
        }
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityIdentifier("page.readyToggle")
    }

    /// An empty ring off; a filled green circle with a ✓ that pops in, on.
    private var mark: some View {
        ZStack {
            Circle()
                .strokeBorder(Palette.ink2, lineWidth: 1.5)
                .opacity(isOn ? 0 : 1)
            Circle()
                .fill(Palette.success)
                .scaleEffect(isOn ? 1 : 0.3)
                .opacity(isOn ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundStyle(Palette.bg)
                .scaleEffect(isOn ? 1 : 0.3)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}
