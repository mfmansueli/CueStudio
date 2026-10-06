//
//  PermissionsService.swift
//  Cue Studio
//

import Foundation

/// Where Camera, Microphone, Speech recognition and Photos stand, for Settings › Privacy & AI data › Permissions. Read from the
/// system each time the page opens or the app comes back from the iPhone's Settings; nothing is asked here.
@MainActor
@Observable
final class PermissionsService {
    private(set) var camera: PermissionState = .notAsked
    private(set) var microphone: PermissionState = .notAsked
    private(set) var speech: PermissionState = .notAsked
    private(set) var photos: PhotosAccess = .notAsked

    @ObservationIgnored private let permissions: PermissionRequesting

    init(permissions: PermissionRequesting) {
        self.permissions = permissions
        refresh()
    }

    func refresh() {
        camera = permissions.camera()
        microphone = permissions.microphone()
        speech = permissions.speech()
        photos = permissions.photos()
    }
}
