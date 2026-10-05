//
//  ScriptChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 3: "Your first script, in your voice." About 15 seconds in the creator's topic, its words born
/// from the light while the AI aura turns around the card, section by section. Without a model the script
/// is ours, labelled as teleprompter practice, and its words fade in without the violet glow.
struct ScriptChapter: View {
    let model: OnboardingViewModel
    let onUse: () -> Void
    let onWriteOwn: () -> Void

    @State private var wordsPlay = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeading(
                label: OnboardingStep.script.chapterLabel, title: String(localized: "Your first script, in your voice."),
                subtitle: String(localized: "A short one to try the teleprompter. You can change every word.")
            )
            .padding(.horizontal, 20)
            card
                .padding(.horizontal, 20)
                .padding(.top, 18)
            Spacer(minLength: 12)
            VStack(spacing: 2) {
                OnboardingPrimaryButton(
                    title: String(localized: "Use this script"), isEnabled: model.scriptState == .ready,
                    shines: model.scriptState == .ready, identifier: "onboarding.useScript", action: onUse
                )
                HStack {
                    OnboardingSecondaryButton(title: String(localized: "Another"), identifier: "onboarding.another") {
                        wordsPlay += 1
                        model.writeScript()
                    }
                    .disabled(model.scriptState == .writing)
                    OnboardingSecondaryButton(title: String(localized: "I’ll write my own"), identifier: "onboarding.writeOwn", action: onWriteOwn)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .onAppear { if model.scriptState == .idle { model.writeScript() } }
        .onDisappear { model.cancelWriting() }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 14) {
            statusLabel
            if let script = model.script, model.scriptState == .ready {
                part(label: "HOOK", text: script.hook, isCurated: script.isCurated)
                part(label: "BODY", text: script.body, isCurated: script.isCurated)
                part(label: "CTA", text: script.cta, isCurated: script.isCurated)
                Text("Written on this iPhone. Nothing leaves it.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.inkHint)
            } else {
                OnboardingWritingNotice()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .aiAura(isActive: model.scriptState == .writing)
        .accessibilityIdentifier("onboarding.scriptCard")
    }

    @ViewBuilder
    private var statusLabel: some View {
        let platform = model.onboarding.platform.label.uppercased()
        if model.scriptState == .writing {
            Text("✦ WRITING FOR \(platform)")
                .font(CueStudioFont.hud).tracking(1.2).foregroundStyle(Palette.aiText)
        } else if model.script?.isCurated == true {
            Text("TELEPROMPTER PRACTICE")
                .font(CueStudioFont.hud).tracking(1.2).foregroundStyle(Palette.inkHint)
        } else {
            Text("✦ READY FOR \(platform) · 15S")
                .font(CueStudioFont.hud).tracking(1.2).foregroundStyle(Palette.aiText)
        }
    }

    private func part(label: String, text: String, isCurated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(label == "HOOK" ? Palette.accText : Palette.inkHint)
            WordsFromLight(
                text: text, font: .system(size: 19, weight: .medium),
                color: isCurated ? Palette.ink : Palette.aiTextStrong, trigger: wordsPlay, glows: !isCurated
            )
        }
    }
}
