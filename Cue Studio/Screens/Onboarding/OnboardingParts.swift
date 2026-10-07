//
//  OnboardingParts.swift
//  Cue Studio
//

import SwiftUI

/// The five-segment bar and "Skip" at the top of the first flight. Skip goes to the Scripts empty state with defaults.
struct OnboardingChrome: View {
    let step: OnboardingStep
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<OnboardingStep.segmentCount, id: \.self) { index in
                let reached = (step.segment ?? -1)
                Capsule()
                    .fill(index < reached ? Color.white.opacity(0.85) : index == reached ? Palette.acc : Palette.fill)
                    .frame(width: 22, height: 4)
            }
            .animation(CueMotion.card, value: step)
            Spacer(minLength: 8)
            // The permissions are asked in the story, not skipped (the board has no "Skip" there).
            if step != .voice { skipButton }
        }
        .padding(.horizontal, 20)
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            Text("Skip")
                .font(.body)
                .foregroundStyle(Palette.ink2)
                // A word, never two lines: it shrinks before it breaks ("Überspringen" at the largest sizes).
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("onboarding.skip")
    }
}

/// A chapter's heading: its label in yellow mono, the title and the line under it. Each rises out of a blur (the boards: 16 pt up, 10 pt of
/// blur, 0.75 s, `cubic-bezier(.16,1,.3,1)`, the three a little apart). A chapter that plays its board gives the pose of each piece at the
/// second it is drawing (`poses`: label, title, line); without them the heading plays its own short arrival.
struct OnboardingHeading: View {
    let label: String
    let title: String
    var subtitle: String?
    var poses: [MotionPose]?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(Palette.accText)
                // The chapter's name wraps rather than ending in "…" when a long language or large type squeezes the page.
                .fixedSize(horizontal: false, vertical: true)
                .motion(pose(0))
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .motion(pose(1, own: MotionPose(opacity: shown ? 1 : 0, ty: shown || reduceMotion ? 0 : 16, blur: shown || reduceMotion ? 0 : 10)))
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .motion(pose(2, own: MotionPose(opacity: shown ? 1 : 0)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard poses == nil else { return }
            withAnimation(CueMotion.animation(CueMotion.light(duration: 0.8), reduced: reduceMotion)) { shown = true }
        }
    }

    /// The board's pose of piece `index`, or the heading's own arrival (`own`) when it has no board; the label has none of its own.
    private func pose(_ index: Int, own: MotionPose = MotionPose()) -> MotionPose {
        guard let poses else { return own }
        return poses.indices.contains(index) ? poses[index] : MotionPose()
    }
}

/// The yellow pill of the first flight: 54 pt, black text, a shine now and then.
struct OnboardingPrimaryButton: View {
    let title: String
    /// What the button says while it cannot be used ("Pick a topic", "Choose a galaxy"); nil keeps `title`.
    var disabledTitle: String?
    /// How it looks then: the yellow pill dimmed to 20% with white text (the default), or a grey one.
    var disabledStyle = DisabledStyle.dimmed
    var isEnabled = true
    var shines = false
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(!isEnabled ? disabledTitle ?? title : title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isGrey ? Palette.ink3 : isDimmed && disabledTitle != nil ? Color.white.opacity(0.8) : Palette.accInk)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(isGrey ? Palette.fill : Palette.acc.opacity(isDimmed ? 0.2 : 1), in: Capsule())
                .modifier(OptionalShine(shines: shines && isEnabled))
                .opacity(isDimmed && disabledTitle == nil ? 0.4 : 1)
        }
        .buttonStyle(PillButtonStyle())
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }

    /// The system dims a disabled button; this one draws its own disabled look (`disabledStyle`) and leaves the label as it is.
    private struct PillButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? 0.85 : 1)
        }
    }

    enum DisabledStyle { case dimmed, grey }

    private var isGrey: Bool { !isEnabled && disabledStyle == .grey }
    private var isDimmed: Bool { !isEnabled && disabledStyle == .dimmed }

    private struct OptionalShine: ViewModifier {
        let shines: Bool
        func body(content: Content) -> some View {
            if shines { content.shineSweep(interval: 5) } else { content }
        }
    }
}

/// The quiet button under the yellow one: text only, at 75% white.
struct OnboardingSecondaryButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
