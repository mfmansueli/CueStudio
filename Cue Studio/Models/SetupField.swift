//
//  SetupField.swift
//  Cue Studio
//

import Foundation

/// One setting of the Creator Setup. A recommendation or a change for one take touches some of
/// them; the rest stay the creator's. The order is the order summaries read in.
nonisolated enum SetupField: String, CaseIterable, Identifiable, Sendable {
    case camera, microphone, format, quality, frameRate, textSize, speed, readingLine, mirror, safeZones

    var id: String { rawValue }

    var label: String {
        switch self {
        case .camera: String(localized: "Camera")
        case .microphone: String(localized: "Microphone")
        case .format: String(localized: "Format")
        case .quality: String(localized: "Quality")
        case .frameRate: String(localized: "Frame rate")
        case .textSize: String(localized: "Text size")
        case .speed: String(localized: "Scroll speed")
        case .readingLine: String(localized: "Reading line")
        case .mirror: String(localized: "Mirror text")
        case .safeZones: String(localized: "Safe zones")
        }
    }
}
