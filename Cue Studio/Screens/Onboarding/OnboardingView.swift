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
    @State private var skyDirector = SkyDirector()
    private let services: AppServices

    @Environment(PresentationService.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(services: AppServices) {
        self.services = services
        _model = State(initialValue: OnboardingViewModel(
            onboarding: services.onboarding,
            permissions: services.permissions,
            library: services.library,
            profile: services.profile,
            ideaDraft: services.ideaDraft,
            presentation: services.presentation
        ))
    }

    private var onboarding: OnboardingService { services.onboarding }

    /// The haze behind the chapter on screen: each board has its own (`BgWash+Presets`).
    private var washLights: [BgWash.Light] {
        switch onboarding.step {
        case .welcome: BgWash.welcome
        case .universe: BgWash.universe
        case .voyage: BgWash.voyage
        case .script: BgWash.message
        case .voice: BgWash.permissions
        case .practice: BgWash.firstStar
        }
    }

    var body: some View {
        // A chapter change moves three depths at three speeds: the chapter (out in 0.22 s, the next in a beat later), the haze behind it
        // (0.8 s) and the sky (0.95 s), so the far things lag the near ones as they would through a window.
        ZStack {
            Palette.Flight.night.ignoresSafeArea()
            BgWash(lights: washLights, base: .clear)
                .id(onboarding.step)
                .transition(.opacity.animation(reduceMotion ? CueMotion.fade : CueMotion.hazeShift))
            OnboardingSky(step: onboarding.step, plays: services.playsWelcomeOpening, frozenAt: services.welcomeFrozenTime)
                .ignoresSafeArea()
                // The sky shifts a little with each chapter (parallax).
                .offset(y: reduceMotion ? 0 : -CGFloat(onboarding.step.rawValue) * 24)
                .animation(CueMotion.skyShift, value: onboarding.step)
            VStack(spacing: 0) {
                if onboarding.step != .welcome {
                    OnboardingChrome(step: onboarding.step, onSkip: skip)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                chapter
                    .id(onboarding.step)
                    .transition(.depth(reduceMotion: reduceMotion))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: onboarding.step)
        .environment(skyDirector)
        .task { HeroDiscCache.prewarm() }
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
            WelcomeChapter(
                plays: services.playsWelcomeOpening, frozenAt: services.welcomeFrozenTime, onStart: advance, onReturning: returning
            )
        case .universe:
            UniverseChapter(
                onboarding: onboarding, plays: services.playsWelcomeOpening, frozenAt: services.chapterFrozenTime,
                birthFrozenAge: services.topicBirthFrozenAge, onContinue: advance
            )
        case .voyage:
            VoyageChapter(
                onboarding: onboarding, plays: services.playsWelcomeOpening, frozenAt: services.chapterFrozenTime,
                frozenPickAge: services.platformPickFrozenAge, onContinue: advance
            )
        case .script:
            ScriptChapter(model: model, plays: services.playsWelcomeOpening, frozenAt: services.chapterFrozenTime, onUse: useScript)
        case .voice:
            VoiceChapter(model: model, onDone: advance, frozenAt: services.chapterFrozenTime)
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

    /// "Try the teleprompter": the practice script becomes a real one in the library, and the flight goes on to the permissions.
    private func useScript() {
        model.applyChoices()
        _ = model.keepScript()
        advance()
    }

    /// The practice run is the real prompter over the front camera, on the practice script of 1.4, not recording.
    private func startPractice() {
        // The script of 1.4 is normally there; a flight opened on this chapter directly gets it here.
        if services.library.scripts.isEmpty {
            let practice = OnboardingScript.practice()
            _ = services.library.create(title: practice.title, text: practice.text, platform: onboarding.platform, language: nil)
        }
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
