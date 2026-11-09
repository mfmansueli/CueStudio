//
//  TelemetryManager.swift
//  Cue Studio
//

import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Foundation

/// Analytics and crash reports, through Firebase (project `cuestudio-app`, `SupportFiles/GoogleService-Info.plist`), only with "Help improve Cue"
/// on (owner, 09/11/2026: both start off, and the switch is the one control). Info.plist keeps both collections off from the very first launch
/// (`FIREBASE_ANALYTICS_COLLECTION_ENABLED`, `FirebaseCrashlyticsCollectionEnabled`); the switch turns them on and off, at launch and on every
/// change (`PrivacyPreferencesService`, through `FirebaseTelemetry`), and Cue's own reports below go out only while it is on. Firebase still
/// starts with the switch off: App Check for Ultra AI's server (`UltraAppCheck`, which fetches nothing until Ultra calls) runs on it.
/// Analytics is `FirebaseAnalyticsCore`, without the advertising identifier, so Cue never asks to track.
enum TelemetryManager {
    /// "Help improve Cue" as the telemetry last heard it. Nothing is reported while it is false.
    private(set) static var isCollecting = false

    /// Starts Firebase unless this launch is a test or a preview (`TelemetryPolicy`), with the creator's choice applied at once. Called once,
    /// before the services load, so a crash while they load is reported too when the switch is on.
    static func start(process: ProcessInfo = .processInfo, defaults: UserDefaults = .standard) {
        guard TelemetryPolicy.sendsReports(arguments: process.arguments, environment: process.environment) else { return }
        UltraAppCheck.install()
        FirebaseApp.configure()
        UltraAppCheck.holdTokensUntilAsked()
        let helps = PrivacyPreferencesService.helpsImprove(in: defaults)
        setCollecting(helps)
        // Crashlytics keeps a crash from a launch with the switch off on this iPhone, waiting to be sent: it never is.
        if !helps { Crashlytics.crashlytics().deleteUnsentReports() }
        DiagnosticsObserver.shared.start()
    }

    /// The switch: Analytics and Crashlytics collect only while it is on. Nothing when Firebase isn't running (tests, previews).
    static func setCollecting(_ isOn: Bool) {
        isCollecting = isOn
        guard FirebaseApp.app() != nil else { return }
        Analytics.setAnalyticsCollectionEnabled(isOn)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(isOn)
    }

    /// What waits on this iPhone to be sent goes: the crash reports not sent yet, and Analytics' events and its id for this install (a new one
    /// starts, so what comes later can't be tied to what came before). Nothing when Firebase isn't running.
    static func discardUnsent() {
        guard FirebaseApp.app() != nil else { return }
        Crashlytics.crashlytics().deleteUnsentReports()
        Analytics.resetAnalyticsData()
    }

    /// Firebase is running and the creator said yes.
    private static var sends: Bool { isCollecting && FirebaseApp.app() != nil }

    /// A freeze, CPU or disk-write problem MetricKit measured on the iPhone, as a non-fatal report: one issue per kind, with how
    /// big it was, the build and the system as keys and the call stack in the log line before it. Never anything the creator
    /// made. Nothing with the switch off or Firebase not running.
    static func record(_ diagnostic: DeviceDiagnosticReport) {
        guard sends else { return }
        let crashlytics = Crashlytics.crashlytics()
        if !diagnostic.callStack.isEmpty { crashlytics.log(diagnostic.callStack) }
        crashlytics.record(error: NSError(domain: diagnostic.domain, code: 0, userInfo: diagnostic.keys))
    }

    /// An Apple Intelligence request that failed in front of the creator, as a non-fatal report (sent with the next launch): one issue
    /// per reason, with the conditions as its keys and the log line before it. Never the words. Nothing with the switch off or Firebase
    /// not running (tests, previews).
    static func record(_ failure: AIFailureReport) {
        guard sends else { return }
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.log(failure.line)
        crashlytics.record(error: NSError(domain: "AppleIntelligence.\(failure.operation).\(failure.reason)", code: 0, userInfo: failure.keys))
    }

    /// An editor or export failure the creator saw, as a non-fatal report (sent with the next launch): one issue per operation and
    /// reason, the conditions and the edit's size as keys, the log line before it. Never the creator's words, files or pictures.
    /// Nothing with the switch off or Firebase not running (tests, previews).
    static func record(_ failure: EditorFailureReport) {
        guard sends else { return }
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.log(failure.line)
        crashlytics.record(error: NSError(domain: failure.issue, code: 0, userInfo: failure.keys))
    }

    /// That a script had to be written once more because it broke what the creator asked (My Cue Voice), as a line in the next report: the kinds of
    /// rule and how much of the voice was sent, never the words. Nothing with the switch off or Firebase not running.
    static func record(_ check: VoiceCheckReport) {
        guard sends else { return }
        Crashlytics.crashlytics().log(check.line)
    }

    /// A notification campaign's outcome (scheduled, opened, a tool used…), as an Analytics event: the campaign, category, outcome and
    /// reason, nothing else. Only called with "Help improve Cue" on (`NotificationService`); nothing with the switch off or Firebase not running.
    static func record(_ event: NotificationTelemetryEvent) {
        guard sends else { return }
        Analytics.logEvent("cue_notification", parameters: event.parameters)
    }

    /// A "+ Something else" answer in My Cue Voice, as an Analytics event: the question and whether it matched one of its options, never the
    /// text. Only called with "Help improve Cue" on (`AppServices`); nothing with the switch off or Firebase not running.
    static func record(_ event: VoiceTypedAnswerEvent) {
        guard sends else { return }
        Analytics.logEvent("cue_voice_typed", parameters: event.parameters)
    }

    /// A first voyage tip shown, acted on or closed, or a step done, as an Analytics event: the step, the place and the outcome, nothing
    /// else. Only called with "Help improve Cue" on (`AppServices`); nothing with the switch off or Firebase not running.
    static func record(_ event: VoyageTelemetryEvent) {
        guard sends else { return }
        Analytics.logEvent("cue_voyage", parameters: event.parameters)
    }

    /// An invite offered, opened, shared or typed, a reward credited, or the rating prompt asked, as an Analytics event: the step, the place and
    /// whether it counted, never the code or the install's id. Only called with "Help improve Cue" on (`AppServices`); nothing with the switch off or
    /// Firebase not running.
    static func record(_ event: ReferralTelemetryEvent) {
        guard sends else { return }
        Analytics.logEvent("cue_referral", parameters: event.parameters)
    }
}
