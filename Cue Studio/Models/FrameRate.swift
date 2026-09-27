//
//  FrameRate.swift
//  Cue Studio
//

import Foundation

nonisolated enum FrameRate: Int, Codable, CaseIterable, Identifiable, Sendable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }

    var label: String { String(rawValue) }
}
