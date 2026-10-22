//
//  PermissionState.swift
//  Cue Studio
//

import AVFoundation
import Photos
import Speech

/// Where a permission stands.
nonisolated enum PermissionState: Equatable, Sendable {
    case notAsked, allowed, denied
}
