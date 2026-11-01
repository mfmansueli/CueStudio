//
//  CameraInterruption.swift
//  Cue Studio
//

import AVFoundation

/// Why the camera stopped for a while without failing: a call or another app took it, iPad shares it with one app at a time (Split View,
/// Slide Over), or the iPhone needs to cool down. The session picks up by itself when it ends (`AVCaptureSession.interruptionEnded`);
/// meanwhile the camera area says so instead of a frozen picture, and nothing records.
nonisolated enum CameraInterruption: Equatable, Sendable {
    case inUseElsewhere
    case multitasking
    case systemPressure
    case paused

    init(reason: AVCaptureSession.InterruptionReason?) {
        switch reason {
        case .audioDeviceInUseByAnotherClient?, .videoDeviceInUseByAnotherClient?: self = .inUseElsewhere
        case .videoDeviceNotAvailableWithMultipleForegroundApps?: self = .multitasking
        case .videoDeviceNotAvailableDueToSystemPressure?: self = .systemPressure
        default: self = .paused
        }
    }

    var title: String {
        switch self {
        case .inUseElsewhere: String(localized: "The camera is in use")
        case .multitasking, .systemPressure, .paused: String(localized: "The camera is paused")
        }
    }

    var detail: String {
        switch self {
        case .inUseElsewhere: String(localized: "A call or another app is using it. It comes back when it’s free.")
        case .multitasking: String(localized: "The camera works with one app at a time. Use Cue in full screen to record.")
        case .systemPressure: String(localized: "This device needs to cool down. The camera comes back in a moment.")
        case .paused: String(localized: "It comes back in a moment.")
        }
    }
}
