//
//  TelemetryManager.swift
//  Cue Studio
//

import FirebaseCore
import Foundation

/// Analytics and crash reports, through Firebase (project `cuestudio-app`, `SupportFiles/GoogleService-Info.plist`).
/// The only place that talks to the Firebase SDK. Once Firebase is configured, Analytics and Crashlytics collect on
/// their own. Analytics is `FirebaseAnalyticsCore`, without the advertising identifier, so Cue never asks to track.
enum TelemetryManager {
    /// Starts Firebase unless this launch is a test or a preview (`TelemetryPolicy`). Called once, before the services
    /// load, so a crash while they load is reported too.
    static func start(process: ProcessInfo = .processInfo) {
        guard TelemetryPolicy.sendsReports(arguments: process.arguments, environment: process.environment) else { return }
        FirebaseApp.configure()
    }
}
