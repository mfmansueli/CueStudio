//
//  ReadyToggle.swift
//  Cue Studio
//

import SwiftUI

/// "Ready to record", beside "Draft" (`DraftChoice`): the pair that moves a script between draft and ready, the only thing on the page
/// that does (leaving never does; recording moves it to recorded). Off, a quiet capsule with an empty ring whose rim breathes, a faint
/// green that comes and goes, so a draft's creator knows where to say it's ready (owner, 02/11/2026); never while they type. On, green
/// with a ✓, and it lights up once as it turns on (the view model plays two soft taps with it); tapping it on does nothing: "Draft" takes
/// it back. Its name says what it does, so leaving the page is never mistaken for it, as "Done" was. Reduce Motion: no glow, and a still
/// rim instead of the breathing one.
struct ReadyToggle: View {
    let isOn: Bool
    /// An empty page has nothing to make ready.
    var isEnabled = true
    /// The page isn't being typed on: the rim may breathe.
    var reminds = true
    let onChange: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The light it gives once as it turns on, 1 → 0.
    @State private var glow: Double = 0
    /// How many breaths the rim has taken: each one plays a breath once.
    @State private var breaths = 0

    /// The first breath waits for the page to settle; then one every few seconds (2.9 s of light, then 8 s dark; owner, 02/11/2026: breaths well apart).
    private static let firstRest: Duration = .seconds(1.2)
    private static let rest: Duration = .seconds(10.9)

    private var showsHint: Bool { !isOn && isEnabled }
    private var isReminding: Bool { showsHint && reminds && !reduceMotion }

    var body: some View {
        Button { if !isOn { onChange(true) } } label: {
            HStack(spacing: 7) {
                mark
                Text("Ready to record")
            }
            .cueFont(14, weight: .semibold)
            .foregroundStyle(isOn ? Palette.successText : Palette.ink)
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: 32)
            .background(isOn ? Palette.Page.readyFill : Palette.fill, in: Capsule())
            .overlay(Capsule().strokeBorder(rim, lineWidth: isOn ? 0.5 : 1))
            .overlay { breathingRim }
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
        .task(id: isReminding) {
            guard isReminding else { return }
            await remind()
        }
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier("page.readyToggle")
    }

    /// On, the green rim; off, under Reduce Motion, a still green rim in the breathing one's place.
    private var rim: Color {
        if isOn { return Palette.Page.readyRim }
        return showsHint && reduceMotion ? Palette.Page.readyHintRim : .clear
    }

    /// The faint green rim that comes and goes; it goes at once when the page is typed on.
    private var breathingRim: some View {
        Capsule()
            .strokeBorder(Palette.Page.readyHintLight, lineWidth: 1)
            .shadow(color: Palette.Page.readyHintLight.opacity(0.6), radius: 3)
            .keyframeAnimator(initialValue: 0.0, trigger: breaths) { rim, opacity in
                rim.opacity(opacity)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.75, duration: 1.3)
                    CubicKeyframe(0, duration: 1.6)
                }
            }
            .opacity(isReminding ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: isReminding)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// A breath, a rest, and again, until the switch turns on, the page is typed on or the page goes.
    private func remind() async {
        var rest = Self.firstRest
        while !Task.isCancelled {
            do { try await Task.sleep(for: rest) } catch { return }
            breaths += 1
            rest = Self.rest
        }
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
                .font(.fixed(8.5, weight: .heavy))
                .foregroundStyle(Palette.bg)
                .scaleEffect(isOn ? 1 : 0.3)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}
