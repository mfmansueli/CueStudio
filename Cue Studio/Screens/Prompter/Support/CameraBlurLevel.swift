//
//  CameraBlurLevel.swift
//  Cue Studio
//

import SwiftUI

/// "Camera blur" in Display: Off, Low, Medium or High, drawn with the system materials behind the
/// Selfie panel (they blur whatever is under them, the camera included).
enum CameraBlurLevel {
    case off, low, medium, high

    init(amount: Double) {
        switch amount {
        case ...0: self = .off
        case ...6: self = .low
        case ...13: self = .medium
        default: self = .high
        }
    }

    var material: Material? {
        switch self {
        case .off: nil
        case .low: .ultraThinMaterial
        case .medium: .thinMaterial
        case .high: .regularMaterial
        }
    }
}
