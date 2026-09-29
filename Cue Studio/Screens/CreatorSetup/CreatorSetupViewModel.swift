//
//  CreatorSetupViewModel.swift
//  Cue Studio
//

import Foundation

/// Profile › Creator Setup: the creator's defaults for every recording ("Set it up once"). Writes
/// the stored preferences directly; recordings start from them, and platform recommendations are
/// offered on top without ever changing them.
@MainActor
@Observable
final class CreatorSetupViewModel {
    /// How far below the front camera the reading line may be set here. The prompter still keeps
    /// it on screen on any iPhone.
    static let readingLineRange: ClosedRange<Double> = 40...320
    static let readingLineStep: Double = 8

    private let preferences: PreferencesService
    private let microphones: MicrophoneListing
    private let toast: ToastService

    init(preferences: PreferencesService, microphones: MicrophoneListing, toast: ToastService) {
        self.preferences = preferences
        self.microphones = microphones
        self.toast = toast
    }

    var setup: CreatorSetup { preferences.creatorSetup }

    // MARK: - Recording

    var usesFrontCamera: Bool { setup.lens.isFront }

    func setFrontCamera(_ front: Bool) {
        update { $0.lens = front ? .front : .wide }
    }

    func setResolution(_ resolution: VideoResolution) {
        update { $0.resolution = resolution }
    }

    func setFrameRate(_ frameRate: FrameRate) {
        update { $0.frameRate = frameRate }
    }

    func setAspect(_ aspect: AspectRatio) {
        update { $0.aspect = aspect }
    }

    // MARK: - Microphone

    var inputs: [MicrophoneOption] { microphones.inputs }

    func refreshInputs() {
        microphones.refreshInputs()
    }

    /// The saved mic, while it isn't connected: it stays the choice, and takes use another one
    /// until it's back.
    var isPreferredMicrophoneMissing: Bool {
        guard let id = setup.microphone.id, !inputs.isEmpty else { return false }
        return !inputs.contains { $0.id == id }
    }

    /// Under "Microphone" in the Recording card.
    var microphoneDetail: String {
        if setup.microphone == .automatic { return String(localized: "The connected mic, or the iPhone's") }
        if isPreferredMicrophoneMissing { return String(localized: "Not connected · takes use another mic until it's back") }
        return String(localized: "Used for every take")
    }

    /// Nil is Automatic.
    func selectMicrophone(_ input: MicrophoneOption?) {
        update { $0.microphone = input.map { .input(id: $0.id, name: $0.name) } ?? .automatic }
    }

    // MARK: - Teleprompter

    var textSizePreset: PrompterTextSize? { PrompterTextSize(points: setup.textSize) }

    func setTextSize(_ preset: PrompterTextSize) {
        update { $0.textSize = preset.points }
    }

    /// Any size the prompter's slider reaches.
    var textSize: Double {
        get { setup.textSize }
        set {
            let range = PrompterSettings.sizeRange
            update { $0.textSize = min(range.upperBound, max(range.lowerBound, newValue.rounded())) }
        }
    }

    var speed: Double {
        get { setup.speed }
        set { update { $0.speed = PrompterSettings.clampedSpeed(newValue) } }
    }

    /// "0.7× · about 150 words a minute"
    var speedDetail: String {
        let words = Int((setup.speed * ReadTime.wordsPerMinuteAtOneX).rounded())
        return String(localized: "\(setup.label(for: .speed)) · about \(words) words a minute")
    }

    /// "118 pt below the camera · recommended"
    var readingLineSummary: String {
        guard let offset = setup.readingLine.offset else {
            return String(localized: "\(Int(ReadingLayout.recommendedFrontOffset)) pt below the camera · recommended")
        }
        return String(localized: "\(Int(offset)) pt below the camera")
    }

    var isReadingLineRecommended: Bool { setup.readingLine == .recommended }

    /// ↑ / ↓: a few points at a time, from where the line is now.
    func nudgeReadingLine(by delta: Double) {
        let current = setup.readingLine.offset ?? Double(ReadingLayout.recommendedFrontOffset)
        let range = Self.readingLineRange
        update { $0.readingLine = .offset(min(range.upperBound, max(range.lowerBound, current + delta))) }
    }

    func resetReadingLine() {
        update { $0.readingLine = .recommended }
    }

    /// The line's look: shown or not. Part of the prompter's settings, saved with them.
    var showsReadingLine: Bool {
        get { preferences.prompter.showsGuide }
        set { preferences.prompter.showsGuide = newValue }
    }

    var isMirrored: Bool {
        get { setup.isMirrored }
        set { update { $0.isMirrored = newValue } }
    }

    var showsSafeZones: Bool {
        get { setup.showsSafeZones }
        set { update { $0.showsSafeZones = newValue } }
    }

    // MARK: - Reset

    /// Preferences only: scripts, takes and edits stay.
    func reset() {
        preferences.resetCreatorSetup()
        toast.show(String(localized: "Creator Setup is back to Cue's defaults"))
    }

    private func update(_ change: (inout CreatorSetup) -> Void) {
        var setup = preferences.creatorSetup
        change(&setup)
        preferences.creatorSetup = setup
    }
}
