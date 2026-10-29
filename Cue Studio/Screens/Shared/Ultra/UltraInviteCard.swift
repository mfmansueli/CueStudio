//
//  UltraInviteCard.swift
//  Cue Studio
//

import SwiftUI

/// The invitation to try Ultra AI (`UltraInviteService`), where the AI writes: a line in the Scripts dock, a card in Find inspiration and on My Cue
/// Voice. It says what Ultra AI is for and that the first scripts are free, with a button to try it (the permission sheet comes first) and × to
/// close it, here and everywhere. Shown only while `UltraScriptService.showsInvite`. The first time it appears in a session it lights up
/// (`UltraMotion`): the ✦ ignites with a glow, the lines rise out of the blur one after the other and a light runs once around the edge; × folds it
/// away with a soft tap. Under Reduce Motion it only fades.
struct UltraInviteCard: View {
    enum Placement {
        /// One line under the dock's field.
        case dock
        /// Above Find inspiration's idea: drafts that idea.
        case inspiration
        /// On My Cue Voice: the next idea goes to Ultra AI.
        case voice
    }

    let placement: Placement
    let onTry: () -> Void
    let onClose: () -> Void

    @Environment(UltraScriptService.self) private var ultra
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The ✦ has ignited and the lines have risen (true at once when the invitation was already seen this session).
    @State private var lit = false
    /// Goes up to play the ✦'s glow and the light's lap.
    @State private var arrival = 0

    private var free: Int { UsagePolicy.freeUltraScripts }

    private var radius: CGFloat { placement == .dock ? 16 : 18 }

    var body: some View {
        Group {
            if placement == .dock { line } else { card }
        }
        .background {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            shape.fill(Palette.aiFill)
                .overlay { if placement != .dock { shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5) } }
                .opacity(lit ? 1 : 0)
                .scaleEffect(lit ? 1 : 0.97, anchor: .top)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : UltraMotion.line, value: lit)
        }
        .overlay { lap }
        .onAppear(perform: arrive)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ultra.invite")
    }

    private var line: some View {
        HStack(spacing: 8) {
            star(.footnote)
            Text("Meet Ultra AI · \(free) free scripts")
                .cueFont(.footnote, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(Rise(lit: lit, step: 1, reduceMotion: reduceMotion))
            tryButton(Text("Try it"), size: .compact)
                .modifier(Rise(lit: lit, step: 2, reduceMotion: reduceMotion))
            closeButton
                .modifier(Rise(lit: lit, step: 2, reduceMotion: reduceMotion))
        }
        .padding(.leading, 14)
        .frame(minHeight: Metrics.hitTarget)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                star(.subheadline)
                Text(title)
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .modifier(Rise(lit: lit, step: 1, reduceMotion: reduceMotion))
                closeButton
                    .padding(.vertical, -12)
                    .modifier(Rise(lit: lit, step: 1, reduceMotion: reduceMotion))
            }
            Text(detail)
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(Rise(lit: lit, step: 2, reduceMotion: reduceMotion))
            tryButton(Text(action), size: .medium)
                .modifier(Rise(lit: lit, step: 3, reduceMotion: reduceMotion))
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 8))
    }

    /// The ✦: it ignites (small, turned, then past its size and back) with a glow that fades.
    private func star(_ style: Font.TextStyle) -> some View {
        let violet = Palette.aiText
        return Text(verbatim: "✦")
            .cueFont(style, weight: .bold)
            .foregroundStyle(violet)
            .keyframeAnimator(initialValue: 0.0, trigger: arrival) { glyph, glow in
                glyph.shadow(color: violet.opacity(glow), radius: 8 * glow)
            } keyframes: { _ in
                LinearKeyframe(1, duration: 0.12)
                LinearKeyframe(1, duration: 0.2)
                CubicKeyframe(0, duration: 0.9)
            }
            .scaleEffect(lit ? 1 : 0.2)
            .rotationEffect(.degrees(lit || reduceMotion ? 0 : -70))
            .opacity(lit ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : UltraMotion.ignite, value: lit)
            .accessibilityHidden(true)
    }

    /// The light's one lap around the edge: a short bright stroke with its glow, running from where the edge starts and fading as it closes.
    private var lap: some View {
        let radius = radius
        let glow = Palette.aiText.opacity(0.45)
        let light = Palette.aiTextStrong
        return Color.clear
            .keyframeAnimator(initialValue: Lap(), trigger: arrival) { _, lap in
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous).trim(from: max(0, lap.head - 0.18), to: lap.head)
                ZStack {
                    shape.stroke(glow, style: StrokeStyle(lineWidth: 4, lineCap: .round)).blur(radius: 3)
                    shape.stroke(light, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }
                .opacity(lap.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.head) {
                    LinearKeyframe(0, duration: UltraMotion.lapDelay)
                    CubicKeyframe(1.18, duration: UltraMotion.lapDuration)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: UltraMotion.lapDelay)
                    LinearKeyframe(1, duration: 0.1)
                    LinearKeyframe(1, duration: UltraMotion.lapDuration - 0.4)
                    CubicKeyframe(0, duration: 0.3)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private struct Lap {
        var head = 0.0
        var opacity = 0.0
    }

    /// Lights up the first time this invitation is seen in the session (`UltraInviteService.takesArrival`); afterwards it is simply there.
    private func arrive() {
        guard !lit else { return }
        let plays = ultra.invite?.takesArrival(of: "\(placement)") ?? true
        guard plays else {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { lit = true }
            return
        }
        lit = true
        if !reduceMotion { arrival += 1 }
    }

    private var title: LocalizedStringKey {
        placement == .voice ? "Your voice, with Ultra AI" : "Draft this idea with Ultra AI"
    }

    private var detail: LocalizedStringKey {
        placement == .voice
            ? "Ultra AI writes in this voice too, and develops each idea further. Your first \(free) scripts are free."
            : "A second writer that develops the idea further, in your voice. Your first \(free) scripts are free."
    }

    private var action: LocalizedStringKey {
        placement == .voice ? "Try Ultra AI free" : "Draft it with Ultra AI"
    }

    private func tryButton(_ label: Text, size: CueStudioButtonStyle.Size) -> some View {
        Button(action: onTry) { label }
            .buttonStyle(.cueAI(size, expands: false))
            .accessibilityIdentifier("ultra.invite.try")
    }

    private var closeButton: some View {
        Button {
            Haptics.soft()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : UltraMotion.fold) { onClose() }
        } label: {
            Image(systemName: "xmark")
                .cueFont(.caption, weight: .bold)
                .foregroundStyle(Palette.ink2)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Not now"))
        .accessibilityHint(Text("Closes the invitation to Ultra AI."))
        .accessibilityIdentifier("ultra.invite.close")
    }
}

/// A line of the invitation rising out of the blur, `step` beats after the ✦.
private struct Rise: ViewModifier {
    let lit: Bool
    let step: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(lit ? 1 : 0)
            .blur(radius: lit || reduceMotion ? 0 : 6)
            .offset(y: lit || reduceMotion ? 0 : 8)
            .animation(
                reduceMotion ? .easeOut(duration: 0.2) : UltraMotion.line.delay(0.08 + Double(step) * UltraMotion.lineStagger), value: lit
            )
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        UltraInviteCard(placement: .dock, onTry: {}, onClose: {})
        UltraInviteCard(placement: .inspiration, onTry: {}, onClose: {})
        UltraInviteCard(placement: .voice, onTry: {}, onClose: {})
    }
    .padding()
    .background(Palette.bg)
    .previewEnvironment()
}
#endif
