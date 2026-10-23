//
//  DeviceFacts.swift
//  Cue Studio
//

import Foundation
import os
import UIKit

/// The iPhone at the moment something failed, as the failure reports keep it (`AIFailureReport`, `EditorFailureReport`): its
/// model, system, heat, Low Power Mode, free memory and whether Cue was in front. Never anything the creator made.
nonisolated enum DeviceFacts {
    /// The hardware model ("iPhone16,1" is an iPhone 15 Pro); the simulated one, marked, in the Simulator.
    static var model: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return "\(simulated) (Simulator)" }
        var info = utsname()
        uname(&info)
        let bytes = withUnsafeBytes(of: info.machine) { Array($0.prefix { $0 != 0 }) }
        return String(bytes: bytes, encoding: .utf8) ?? "unknown"
    }

    /// "26.1.0".
    static var system: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    /// `ProcessInfo.ThermalState`: "nominal", "fair", "serious" or "critical".
    static var thermal: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    static var lowPower: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }

    /// Memory the app could still use, in MB.
    static var freeMemoryMB: Int { Int(os_proc_available_memory() / 1_048_576) }

    /// "active", "inactive" or "background".
    @MainActor
    static var appState: String {
        switch UIApplication.shared.applicationState {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }
}
