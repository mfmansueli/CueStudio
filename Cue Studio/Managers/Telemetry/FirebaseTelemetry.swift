//
//  FirebaseTelemetry.swift
//  Cue Studio
//

import Foundation

/// The switch reaching Firebase's Analytics and Crashlytics (`TelemetryManager`).
final class FirebaseTelemetry: TelemetryCollecting {
    func setCollecting(_ isOn: Bool) {
        TelemetryManager.setCollecting(isOn)
    }

    func discardUnsent() {
        TelemetryManager.discardUnsent()
    }
}
