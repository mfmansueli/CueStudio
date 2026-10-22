//
//  StubPermissions.swift
//  Cue Studio
//

import AVFoundation
import Photos
import Speech

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
    func photos() -> PhotosAccess { .notAsked }

    func requestMicrophone() async -> PermissionState { remember("mic") }
    func requestSpeech() async -> PermissionState { remember("speech") }
    func requestCamera() async -> PermissionState { remember("camera") }

    private func remember(_ key: String) -> PermissionState {
        states[key] = answer
        return answer
    }
}
