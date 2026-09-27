//
//  VideoCodec.swift
//  Cue Studio
//

import Foundation

nonisolated enum VideoCodec: String, Codable, CaseIterable, Identifiable, Sendable {
    case hevc, h264

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hevc: "HEVC"
        case .h264: "H.264"
        }
    }
}
