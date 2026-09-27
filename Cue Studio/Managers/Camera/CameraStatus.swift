//
//  CameraStatus.swift
//  Cue Studio
//

import Foundation

nonisolated enum CameraStatus: Equatable, Sendable {
    case idle
    case starting
    case running
    /// Camera access was denied.
    case unauthorized
    /// No camera on this device (Simulator, some Macs).
    case unavailable
    case failed(String)
}
