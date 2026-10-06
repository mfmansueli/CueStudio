//
//  OnboardingViewModel.swift
//  Cue Studio
//

import Foundation

/// The first flight's work between the chapters: it writes the first script (the model, or ours when there
/// is no model), asks for the permissions in order and, at the end, puts what the creator picked where
/// the rest of the app reads it.
@MainActor
@Observable
final class OnboardingViewModel {
    enum ScriptState: Equatable {
        case idle, writing, ready
    }

    let onboarding: OnboardingService
    private(set) var script: OnboardingScript?
    private(set) var scriptState: ScriptState = .idle
    /// How many scripts were asked for: "Another" shows a different phrasing each time.
    private(set) var attempts = 0
    /// When the model was asked, and when its message arrived: the card's slow states (09 §16) count from the first, its words arrive from the second.
    private(set) var writingStartedAt: Date?
    private(set) var readyAt: Date?
    /// The model took too long and Cue wrote the built-in message by itself (the chapter says so with a toast).
    private(set) var fellBackByItself = false
    private(set) var microphone: PermissionState
    private(set) var speech: PermissionState
    private(set) var camera: PermissionState
    private(set) var isAskingPermissions = false

    private let writer: ScriptWriting
    private let factory: ScriptRequestFactory
    private let permissions: PermissionRequesting
    private let library: ScriptLibraryService
    private let profile: CreatorProfileService
    private let ideaDraft: IdeaDraftService
    private let presentation: PresentationService
    private var writingTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?

    init(
        onboarding: OnboardingService, writer: ScriptWriting, factory: ScriptRequestFactory, permissions: PermissionRequesting,
        library: ScriptLibraryService, profile: CreatorProfileService, ideaDraft: IdeaDraftService, presentation: PresentationService
    ) {
        self.onboarding = onboarding
        self.writer = writer
        self.factory = factory
        self.permissions = permissions
        self.library = library
        self.profile = profile
        self.ideaDraft = ideaDraft
        self.presentation = presentation
        microphone = permissions.microphone()
        speech = permissions.speech()
        camera = permissions.camera()
    }

    // MARK: - The first script

    /// "✦ WRITING FOR TIKTOK" while the model writes, "READY FOR TIKTOK · 15S" after. Without a model the
    /// practice script is shown at once and labelled as practice.
    var usesModel: Bool { writer.isLanguageModelAvailable }

    func writeScript() {
        writingTask?.cancel()
        let topic = onboarding.mainTopic?.label ?? String(localized: "your day")
        attempts += 1
        fellBackByItself = false
        readyAt = nil
        writingStartedAt = .now
        guard usesModel else {
            useBuiltIn(topic: topic)
            return
        }
        scriptState = .writing
        let idea = String(localized: "A 15-second script to try a teleprompter, about \(topic)")
        var request = factory.request(idea: idea, platform: onboarding.platform, format: nil)
        request.targetRange = 12...18
        writingTask = Task { [weak self, writer] in
            do {
                let generated = try await writer.generate(request)
                guard !Task.isCancelled, let self else { return }
                script = .parsing(title: generated.title.isEmpty ? topic : generated.title, text: generated.text)
                scriptState = .ready
                readyAt = .now
            } catch {
                guard !Task.isCancelled, let self else { return }
                // No model after all, or a language it can't write: ours, as practice.
                useBuiltIn(topic: topic)
            }
        }
        // Past 25 s without an answer Cue writes the built-in message by itself (09 §16).
        fallbackTask?.cancel()
        fallbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.fallbackAfter))
            guard !Task.isCancelled, let self, scriptState == .writing else { return }
            writingTask?.cancel()
            fellBackByItself = true
            useBuiltIn(topic: topic)
        }
    }

    /// "Use a ready-made message" (after 15 s of waiting): the built-in message for the topic, at once.
    func useReadyMade() {
        writingTask?.cancel()
        useBuiltIn(topic: onboarding.mainTopic?.label ?? String(localized: "your day"))
    }

    /// How long the model may take before Cue writes the message itself.
    static let fallbackAfter = 25.0

    private func useBuiltIn(topic: String) {
        script = .curated(topic: topic)
        scriptState = .ready
        readyAt = .now
    }

    func cancelWriting() {
        writingTask?.cancel()
        writingTask = nil
        fallbackTask?.cancel()
        fallbackTask = nil
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
        cancelWriting()
        applyChoices()
        onboarding.complete()
        presentation.selectedTab = .scripts
    }
}
