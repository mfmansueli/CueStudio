//
//  TelemetryManager.swift
//  Cue Studio
//

import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
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

    /// An Apple Intelligence request that failed in front of the creator, as a non-fatal report (sent with the next launch): one issue
    /// per reason, with the conditions as its keys and the log line before it. Never the words. Nothing when Firebase isn't running
    /// (tests, previews).
    static func record(_ failure: AIFailureReport) {
        guard FirebaseApp.app() != nil else { return }
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.log(failure.line)
        crashlytics.record(error: NSError(domain: "AppleIntelligence.\(failure.operation).\(failure.reason)", code: 0, userInfo: failure.keys))
    }

    /// That a script had to be written once more because it broke what the creator asked (My Cue Voice), as a line in the next report: the kinds of
    /// rule and how much of the voice was sent, never the words. Nothing when Firebase isn't running (tests, previews).
    static func record(_ check: VoiceCheckReport) {
        guard FirebaseApp.app() != nil else { return }
        Crashlytics.crashlytics().log(check.line)
    }

    /// A notification campaign's outcome (scheduled, opened, a tool used…), as an Analytics event: the campaign, category, outcome and
    /// reason, nothing else. Only called with "Help improve Cue" on (`NotificationService`); nothing when Firebase isn't running.
    static func record(_ event: NotificationTelemetryEvent) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent("cue_notification", parameters: event.parameters)
    }
}
