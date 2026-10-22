//
//  PermissionRequesting.swift
//  Cue Studio
//

import AVFoundation
import Photos
import Speech

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
    /// Cue saves videos to Photos and asks for nothing more than adding them; the answer is read, never asked here.
    func photos() -> PhotosAccess
}
