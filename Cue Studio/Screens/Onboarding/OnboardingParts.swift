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
        HStack(spacing: 6) {
            ForEach(0..<OnboardingStep.segmentCount, id: \.self) { index in
                let reached = (step.segment ?? -1)
                Capsule()
                    .fill(index < reached ? Color.white.opacity(0.85) : index == reached ? Palette.acc : Palette.fill)
                    .frame(width: 26, height: 4)
            }
            .animation(CueMotion.card, value: step)
            Spacer(minLength: 8)
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
        .padding(.horizontal, 20)
    }
}

/// A chapter's heading: its label in yellow mono, the title (the words rise out of a blur) and the line under it.
struct OnboardingHeading: View {
    let label: String
    let title: String
    var subtitle: String?

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
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .blur(radius: shown || reduceMotion ? 0 : 10)
                .offset(y: shown || reduceMotion ? 0 : 16)
                .opacity(shown ? 1 : 0)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(shown ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(CueMotion.animation(CueMotion.light(duration: 0.8), reduced: reduceMotion)) { shown = true }
        }
    }
}

/// The yellow pill of the first flight: 54 pt, black text, a shine now and then.
struct OnboardingPrimaryButton: View {
    let title: String
    var isEnabled = true
    var shines = false
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.accInk)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Palette.acc, in: Capsule())
                .modifier(OptionalShine(shines: shines && isEnabled))
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }

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

/// A mono label in a chapter: "3 OF 3 · TAP TO CHANGE".
struct OnboardingCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(CueStudioFont.hud)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Palette.inkHint)
    }
}
