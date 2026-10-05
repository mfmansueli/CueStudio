//
//  PermissionRequesting.swift
//  Cue Studio
//

import AVFoundation
import Speech

/// Where a permission stands.
nonisolated enum PermissionState: Equatable, Sendable {
    case notAsked, allowed, denied
}

/// The permissions the first flight asks for, in the story: microphone, speech recognition (Voice
/// Following) and camera. Tests swap in a stub, because the simulator's prompts are not the point.
@MainActor
protocol PermissionRequesting: AnyObject {
    func microphone() -> PermissionState
    func requestMicrophone() async -> PermissionState
    func speech() -> PermissionState
    func requestSpeech() async -> PermissionState
    func camera() -> PermissionState
    func requestCamera() async -> PermissionState
}

/// The real thing: the system's own prompts.
@MainActor
final class SystemPermissions: PermissionRequesting {
    func microphone() -> PermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .allowed
        case .denied: .denied
        default: .notAsked
        }
    }

    func requestMicrophone() async -> PermissionState {
        await AVAudioApplication.requestRecordPermission() ? .allowed : .denied
    }

    func speech() -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .allowed
        case .denied, .restricted: .denied
        default: .notAsked
        }
    }

    func requestSpeech() async -> PermissionState {
        await Self.speechAuthorization() == .authorized ? .allowed : .denied
    }

    /// Speech answers on a queue of its own: the callback must not be isolated to the main actor (it would trap).
    private nonisolated static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    func camera() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .allowed
        case .denied, .restricted: .denied
        default: .notAsked
        }
    }

    func requestCamera() async -> PermissionState {
        await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .denied
    }
}

/// UI tests and previews: every request is answered the same way, at once.
@MainActor
final class StubPermissions: PermissionRequesting {
    private var states: [String: PermissionState] = [:]
    private let answer: PermissionState

    init(grants: Bool) {
        answer = grants ? .allowed : .denied
    }

    func microphone() -> PermissionState { states["mic"] ?? .notAsked }
    func speech() -> PermissionState { states["speech"] ?? .notAsked }
    func camera() -> PermissionState { states["camera"] ?? .notAsked }

    func requestMicrophone() async -> PermissionState { remember("mic") }
    func requestSpeech() async -> PermissionState { remember("speech") }
    func requestCamera() async -> PermissionState { remember("camera") }

    private func remember(_ key: String) -> PermissionState {
        states[key] = answer
        return answer
    }
}
