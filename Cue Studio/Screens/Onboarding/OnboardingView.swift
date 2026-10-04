//
//  OnboardingView.swift
//  Cue Studio
//

import SwiftUI

/// The first flight: a welcome and five short chapters over a night sky, ending with a practice run of the
/// teleprompter. It lies over the whole app (not a cover, so the prompter can open above it) until it is
/// finished or skipped.
struct OnboardingView: View {
    @State private var model: OnboardingViewModel
    private let services: AppServices

    @Environment(PresentationService.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(services: AppServices) {
        self.services = services
        _model = State(initialValue: OnboardingViewModel(
            onboarding: services.onboarding,
            writer: services.writer,
            factory: services.starter.factory,
            permissions: services.permissions,
            library: services.library,
            profile: services.profile,
            ideaDraft: services.ideaDraft,
            presentation: services.presentation
        ))
    }

    private var onboarding: OnboardingService { services.onboarding }

    var body: some View {
        ZStack {
            Color(hex: 0x07080E).ignoresSafeArea()
            StarfieldView(density: .calm, seed: 7)
                .ignoresSafeArea()
                // The sky shifts a little with each chapter (parallax).
                .offset(y: reduceMotion ? 0 : -CGFloat(onboarding.step.rawValue) * 24)
                .animation(.easeInOut(duration: 0.6), value: onboarding.step)
            VStack(spacing: 0) {
                if onboarding.step != .welcome {
                    OnboardingChrome(step: onboarding.step, onSkip: skip)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                chapter
                    .id(onboarding.step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale(scale: 1.04).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: onboarding.step)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.root")
        // The prompter closed during the practice: the story is over either way.
        .onChange(of: presentation.prompter == nil) { _, closed in
            if closed, onboarding.step == .practice { model.finish() }
        }
    }

    @ViewBuilder
    private var chapter: some View {
        switch onboarding.step {
        case .welcome:
            WelcomeChapter(onStart: advance, onReturning: returning)
        case .universe:
            UniverseChapter(onboarding: onboarding, onContinue: advance)
        case .voyage:
            VoyageChapter(onboarding: onboarding, onContinue: advance)
        case .script:
            ScriptChapter(model: model, onUse: useScript, onWriteOwn: writeOwn)
        case .voice:
            VoiceChapter(model: model, onDone: advance)
        case .practice:
            PracticeChapter()
                .onAppear(perform: startPractice)
        }
    }

    // MARK: - Moving

    private func advance() {
        Haptics.selection()
        onboarding.advance()
    }

    /// "Skip": straight to the Scripts empty state, with what was picked so far (and TikTok if nothing).
    private func skip() {
        model.finish()
    }

    /// "I already use Cue": the story is not for them. Restoring purchases and signing in live in Profile.
    private func returning() {
        model.finish()
        presentation.selectedTab = .profile
    }

    /// "Use this script": it becomes a real script; "Another" and "I'll write my own" are the other ways out.
    private func useScript() {
        model.applyChoices()
        _ = model.keepScript()
        advance()
    }

    /// "I'll write my own": the picks are kept and Scripts opens on a blank page.
    private func writeOwn() {
        model.finish()
        let script = services.library.create(
            title: "", text: "", platform: onboarding.platform, language: services.languages.scriptLanguage
        )
        presentation.openScript(script.id, editing: true)
    }

    /// The practice run is the real prompter over the front camera, on the script just made, not recording.
    private func startPractice() {
        let scriptID = services.library.scripts.first?.id
        presentation.prompter = PrompterLaunch(scriptID: scriptID, mode: .selfie, isPractice: true)
    }
}

/// What is under the prompter while the creator practices.
struct PracticeChapter: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView().tint(Palette.accText)
            Spacer()
        }
        .accessibilityHidden(true)
    }
}
