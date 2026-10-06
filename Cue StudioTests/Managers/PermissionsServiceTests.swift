//
//  PermissionsServiceTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Settings › Privacy & AI data › Permissions reads where each permission stands; it never asks.
@MainActor
@Suite("PermissionsService")
struct PermissionsServiceTests {
    @MainActor
    private final class Answers: PermissionRequesting {
        var cameraState: PermissionState = .notAsked
        var microphoneState: PermissionState = .notAsked
        var speechState: PermissionState = .notAsked
        var photosState: PhotosAccess = .notAsked
        private(set) var requests = 0

        func microphone() -> PermissionState { microphoneState }
        func requestMicrophone() async -> PermissionState { requests += 1; return microphoneState }
        func speech() -> PermissionState { speechState }
        func requestSpeech() async -> PermissionState { requests += 1; return speechState }
        func camera() -> PermissionState { cameraState }
        func requestCamera() async -> PermissionState { requests += 1; return cameraState }
        func photos() -> PhotosAccess { photosState }
    }

    @Test func readsEveryPermissionAtStartAndOnRefresh() {
        let answers = Answers()
        answers.cameraState = .allowed
        answers.photosState = .addOnly
        let service = PermissionsService(permissions: answers)
        #expect(service.camera == .allowed)
        #expect(service.photos == .addOnly)
        #expect(service.microphone == .notAsked)

        answers.microphoneState = .denied
        answers.speechState = .allowed
        service.refresh()
        #expect(service.microphone == .denied)
        #expect(service.speech == .allowed)
        #expect(answers.requests == 0, "reading a permission never asks for it")
    }
}
