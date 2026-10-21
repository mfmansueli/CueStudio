//
//  SystemPermissions.swift
//  Cue Studio
//

import AVFoundation
import Photos
import Speech

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

    func photos() -> PhotosAccess {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: return .full
        default: break
        }
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited: return .addOnly
        case .denied, .restricted: return .denied
        default: return .notAsked
        }
    }
}
