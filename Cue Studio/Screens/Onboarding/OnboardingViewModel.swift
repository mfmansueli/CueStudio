//
//  OnboardingViewModel.swift
//  Cue Studio
//

import Foundation

/// The first flight's work between the chapters: it hands 1.4 the practice script (the same for everyone, `OnboardingScript.practice`), asks
/// for the permissions in order and, at the end, puts what the creator picked where the rest of the app reads it.
@MainActor
@Observable
final class OnboardingViewModel {
    let onboarding: OnboardingService
    private(set) var script: OnboardingScript?
    /// When the practice script arrived on 1.4: the card's words arrive from it, in the board's rhythm.
    private(set) var readyAt: Date?
    private(set) var microphone: PermissionState
    private(set) var speech: PermissionState
    private(set) var camera: PermissionState
    private(set) var isAskingPermissions = false

    private let permissions: PermissionRequesting
    private let library: ScriptLibraryService
    private let profile: CreatorProfileService
    private let ideaDraft: IdeaDraftService
    private let presentation: PresentationService

    init(
        onboarding: OnboardingService, permissions: PermissionRequesting, library: ScriptLibraryService, profile: CreatorProfileService,
        ideaDraft: IdeaDraftService, presentation: PresentationService
    ) {
        self.onboarding = onboarding
        self.permissions = permissions
        self.library = library
        self.profile = profile
        self.ideaDraft = ideaDraft
        self.presentation = presentation
        microphone = permissions.microphone()
        speech = permissions.speech()
        camera = permissions.camera()
    }

    // MARK: - The practice script

    /// 1.4 opens: the practice script is there at once (nothing is written; the card shows it arriving).
    func prepareScript() {
        guard script == nil else { return }
        script = .practice()
        readyAt = .now
    }

    // MARK: - Permissions

    /// Whatever the answers, the flight goes on: a denial never blocks the app.
    var hasAnsweredEverything: Bool {
        microphone != .notAsked && camera != .notAsked
    }

    /// Something was refused: the screen says, gently, that the practice still works and where to turn it on.
    var hasDenied: Bool {
        microphone == .denied || camera == .denied
    }

    /// "Continue" on the permissions screen: the system's prompts follow one at a time, microphone first.
    func askPermissions() async {
        guard !isAskingPermissions else { return }
        isAskingPermissions = true
        defer { isAskingPermissions = false }
        await requestMicrophoneAndSpeech()
        await requestCameraAccess()
    }

    /// The microphone's row: the system's prompt for it (and for Speech, which Voice Following listens through).
    func askMicrophone() async {
        guard !isAskingPermissions else { return }
        isAskingPermissions = true
        defer { isAskingPermissions = false }
        await requestMicrophoneAndSpeech()
    }

    /// The camera's row.
    func askCamera() async {
        guard !isAskingPermissions else { return }
        isAskingPermissions = true
        defer { isAskingPermissions = false }
        await requestCameraAccess()
    }

    /// Back from Settings, where the creator may have turned something on.
    func refreshPermissions() {
        microphone = permissions.microphone()
        speech = permissions.speech()
        camera = permissions.camera()
    }

    private func requestMicrophoneAndSpeech() async {
        if microphone == .notAsked {
            microphone = await permissions.requestMicrophone()
            if microphone == .allowed { Haptics.success() }
        }
        // Voice Following listens through Speech: it is part of the microphone's story.
        if speech == .notAsked, microphone == .allowed {
            speech = await permissions.requestSpeech()
        }
    }

    private func requestCameraAccess() async {
        if camera == .notAsked {
            camera = await permissions.requestCamera()
            if camera == .allowed { Haptics.success() }
        }
    }

    // MARK: - The end

    /// The script becomes a real one in the library, for the platform picked.
    @discardableResult
    func keepScript() -> Script? {
        guard let script else { return nil }
        let created = library.create(
            title: script.title, text: script.text, platform: onboarding.platform, language: nil
        )
        return created
    }

    /// What the creator picked goes where the rest of the app reads it: topics, the default platform and the card's platform.
    func applyChoices() {
        let niches = onboarding.topics.compactMap { topic -> Niche? in
            if case .niche(let niche) = topic { niche } else { nil }
        }
        let customs = onboarding.topics.compactMap { topic -> String? in
            if case .custom(let name) = topic { name } else { nil }
        }
        profile.applyFirstFlight(niches: niches, customTopics: customs, platform: onboarding.platform)
        ideaDraft.platform = onboarding.platform
    }

    /// Wraps the flight up: the choices are kept and the app opens on Scripts.
    func finish() {
        applyChoices()
        onboarding.complete()
        presentation.selectedTab = .scripts
    }
}
