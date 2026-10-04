//
//  VoiceChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 4: "Your script is ready. Now it needs you." The microphone and the camera, asked in the story. The
/// only button is Continue, and the system's own alert follows it; there is no Skip and no "Not now" here, and a
/// refusal never blocks the app (the prompter then scrolls at a steady pace and asks again in context).
struct VoiceChapter: View {
    let model: OnboardingViewModel
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .accessibilityHidden(true)
            OnboardingHeading(
                label: OnboardingStep.voice.chapterLabel, title: String(localized: "Your script is ready. Now it needs you."),
                subtitle: String(localized: "Cue listens so the text can follow your voice, and uses the camera so you can see your framing. Everything stays on this iPhone.")
            )
            .padding(.horizontal, 20)
            VStack(spacing: 0) {
                row(
                    icon: .followsVoice, title: String(localized: "Microphone"), detail: String(localized: "So the text follows your voice"),
                    tint: Palette.accText, state: model.microphone, isNext: model.microphone == .notAsked, identifier: "microphone"
                )
                Divider().overlay(Palette.separator)
                row(
                    icon: .flipCamera, title: String(localized: "Camera"), detail: String(localized: "So you can see yourself while you read"),
                    tint: Palette.aiText, state: model.camera, isNext: model.microphone != .notAsked && model.camera == .notAsked, identifier: "camera"
                )
            }
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
            .padding(.horizontal, 20)
            .padding(.top, 20)
            Text("You can change this anytime in Settings. Cue never records until you tap Record.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkHint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 14)
            Spacer(minLength: 12)
            OnboardingPrimaryButton(
                title: String(localized: "Continue"), isEnabled: !model.isAskingPermissions,
                identifier: "onboarding.continue"
            ) {
                Task {
                    if !model.hasAnsweredEverything { await model.askPermissions() }
                    try? await Task.sleep(for: .milliseconds(600))
                    onDone()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    /// A microphone orb with level bars and rings, a dotted way to the camera orb with its iris.
    private var art: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 46) {
                ZStack {
                    ForEach(0..<2, id: \.self) { ring in
                        Circle()
                            .strokeBorder(Palette.acc.opacity(0.35 - Double(ring) * 0.15), lineWidth: 1)
                            .frame(width: 98 + CGFloat(ring) * 40 + CGFloat(sin(time * 2 + Double(ring))) * 4)
                    }
                    Circle().fill(Palette.acc.opacity(0.14)).overlay(Circle().strokeBorder(Palette.acc.opacity(0.7), lineWidth: 1.5)).frame(width: 98)
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { bar in
                            Capsule()
                                .fill(Palette.acc)
                                .frame(width: 4, height: 14 + CGFloat(abs(sin(time * 3 + Double(bar) * 0.9))) * 26)
                        }
                    }
                }
                .frame(width: 140, height: 140)
                ZStack {
                    Circle().fill(Palette.aiFill).overlay(Circle().strokeBorder(Palette.aiBorder, lineWidth: 1.5)).frame(width: 98)
                    Circle().strokeBorder(Palette.aiText.opacity(0.8), lineWidth: 2).frame(width: 62)
                    Circle().fill(Palette.aiText.opacity(0.35)).frame(width: 40)
                }
            }
        }
    }

    private func row(
        icon: CueIcon, title: String, detail: String, tint: Color, state: PermissionState, isNext: Bool, identifier: String
    ) -> some View {
        HStack(spacing: 14) {
            CueIconView(icon, size: 22)
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 14)).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 8)
            stateBadge(state, isNext: isNext)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.permission.\(identifier)")
    }

    @ViewBuilder
    private func stateBadge(_ state: PermissionState, isNext: Bool) -> some View {
        switch state {
        case .allowed:
            Text("✓ Allowed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.successText)
                .padding(.horizontal, 12).frame(height: 32)
                .background(Palette.success.opacity(0.16), in: Capsule())
        case .denied:
            Text("Off")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.warnText)
                .padding(.horizontal, 12).frame(height: 32)
                .background(Palette.warnSoft, in: Capsule())
        case .notAsked:
            if isNext {
                Text("Next")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.accText)
                    .padding(.horizontal, 12).frame(height: 32)
                    .overlay(Capsule().strokeBorder(Palette.acc.opacity(0.6), lineWidth: 1))
            }
        }
    }
}
