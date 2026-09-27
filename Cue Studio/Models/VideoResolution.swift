//
//  VideoResolution.swift
//  Cue Studio
//

import Foundation

nonisolated enum VideoResolution: String, Codable, CaseIterable, Identifiable, Sendable {
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4K = "4K"

    var id: String { rawValue }

    var label: String { rawValue }

    /// Sensor dimensions in landscape orientation, as AVFoundation reports them.
    var landscapeWidth: Int {
        switch self {
        case .hd720: 1280
        case .hd1080: 1920
        case .uhd4K: 3840
        }
    }

    var landscapeHeight: Int {
        switch self {
        case .hd720: 720
        case .hd1080: 1080
        case .uhd4K: 2160
        }
    }
}
