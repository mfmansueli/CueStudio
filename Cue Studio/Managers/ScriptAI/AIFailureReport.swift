//
//  AIFailureReport.swift
//  Cue Studio
//

import Foundation
import FoundationModels
import os
import UIKit

/// One Apple Intelligence request that failed, as the log and the crash reports keep it: what was asked, on which model, the
/// framework's own reason ("guardrailViolation", "timeout", "concurrentRequests"…) and the iPhone at that moment (whether the model
/// was ready, heat, Low Power Mode, free memory, the app in front or not). Never the creator's words, nor the model's.
///
/// In Console: subsystem `studio.cue`, category `ScriptAI`. A failure the creator was told about is also a non-fatal report in
/// Crashlytics (`TelemetryManager.record(_:)`), one issue per reason.
nonisolated struct AIFailureReport: Equatable, Sendable {
    /// What was asked: "script", "rewrite", "hooks" or "themes".
    var operation: String
    /// The model that failed; nil when no model was tried (the request was turned down before it went out).
    var route: AIModelRoute?
    /// The framework's case ("guardrailViolation", "contextSizeExceeded(4100/4096)"), or Cue's ("cue.emptyResponse").
    var reason: String
    /// The framework's message for developers: what failed, never what was written.
    var detail: String
    /// The language the script is in (BCP 47); nil when it is told by the words.
    var language: String?
    /// Seconds from sending the request to the failure.
    var seconds: Double
    /// The creator was told (no other try was left); otherwise it was tried again.
    var isFinal: Bool
    var conditions: Conditions

    /// The iPhone when the request failed.
    nonisolated struct Conditions: Equatable, Sendable {
        /// The hardware model ("iPhone16,1" is an iPhone 15 Pro).
        var device: String
        var system: String
        /// The device model's availability then ("available", "modelNotReady"…).
        var model: String
        /// `ProcessInfo.ThermalState`: "nominal", "fair", "serious" or "critical".
        var thermal: String
        var lowPower: Bool
        /// Memory the app could still use, in MB.
        var freeMemoryMB: Int
        /// "active", "inactive" or "background".
        var appState: String

        /// Now, with the app's state as the caller (on the main actor) sees it.
        static func current(appState: String) -> Conditions {
            let process = ProcessInfo.processInfo
            let version = process.operatingSystemVersion
            return Conditions(
                device: deviceModel,
                system: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
                model: modelAvailability,
                thermal: name(of: process.thermalState),
                lowPower: process.isLowPowerModeEnabled,
                freeMemoryMB: Int(os_proc_available_memory() / 1_048_576),
                appState: appState
            )
        }

        private static var deviceModel: String {
            if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return "\(simulated) (Simulator)" }
            var info = utsname()
            uname(&info)
            let bytes = withUnsafeBytes(of: info.machine) { Array($0.prefix { $0 != 0 }) }
            return String(bytes: bytes, encoding: .utf8) ?? "unknown"
        }

        private static var modelAvailability: String {
            switch SystemLanguageModel.default.availability {
            case .available: "available"
            case .unavailable(.deviceNotEligible): "deviceNotEligible"
            case .unavailable(.appleIntelligenceNotEnabled): "appleIntelligenceNotEnabled"
            case .unavailable(.modelNotReady): "modelNotReady"
            case .unavailable: "unavailable"
            }
        }

        private static func name(of state: ProcessInfo.ThermalState) -> String {
            switch state {
            case .nominal: "nominal"
            case .fair: "fair"
            case .serious: "serious"
            case .critical: "critical"
            @unknown default: "unknown"
            }
        }
    }

    // MARK: - Reasons

    /// The case an error is, by name, with the framework's developer message: the framework's errors are told apart by their own cases
    /// (all but a few of them are "Couldn't write it" to the creator).
    static func reason(of error: any Error) -> (reason: String, detail: String) {
        switch error {
        case is CancellationError:
            return ("cancelled", "")
        case let error as LanguageModelError:
            return reason(of: error)
        case let error as LanguageModelSession.Error:
            return (name(of: error), "")
        case let error as SystemLanguageModel.Error:
            if case .assetsUnavailable = error { return ("assetsUnavailable", error.debugDescription) }
            return ("systemModel.unknown", error.debugDescription)
        case let error as PrivateCloudComputeLanguageModel.Error:
            return (name(of: error), error.debugDescription)
        case let error as ScriptAIError:
            return ("cue.\(name(of: error))", "")
        case let error as AIPlanFailure:
            return ("plan.\(name(of: error))", "")
        default:
            // Something else (a structured answer that couldn't be read, a system error): its type, domain and code.
            let bridged = error as NSError
            return ("\(String(reflecting: type(of: error))) \(bridged.domain) \(bridged.code)", "")
        }
    }

    private static func reason(of error: LanguageModelError) -> (reason: String, detail: String) {
        switch error {
        case .contextSizeExceeded(let context):
            ("contextSizeExceeded(\(context.tokenCount)/\(context.contextSize))", context.debugDescription)
        case .rateLimited(let context):
            ("rateLimited", context.debugDescription + (context.resetDate.map { " reset \($0.formatted(.iso8601))" } ?? ""))
        case .guardrailViolation(let context): ("guardrailViolation", context.debugDescription)
        case .refusal(let context): ("refusal", context.debugDescription)
        case .unsupportedCapability(let context): ("unsupportedCapability", context.debugDescription)
        case .unsupportedTranscriptContent(let context): ("unsupportedTranscriptContent", context.debugDescription)
        case .unsupportedGenerationGuide(let context): ("unsupportedGenerationGuide", context.debugDescription)
        case .unsupportedLanguageOrLocale(let context): ("unsupportedLanguageOrLocale", context.debugDescription)
        case .timeout(let context): ("timeout", context.debugDescription)
        @unknown default: ("languageModel.unknown", "")
        }
    }

    private static func name(of error: LanguageModelSession.Error) -> String {
        switch error {
        case .concurrentRequests: "concurrentRequests"
        case .transcriptMutationWhileResponding: "transcriptMutationWhileResponding"
        @unknown default: "session.unknown"
        }
    }

    private static func name(of error: PrivateCloudComputeLanguageModel.Error) -> String {
        switch error {
        case .networkFailure: "cloud.networkFailure"
        case .quotaLimitReached: "cloud.quotaLimitReached"
        case .serviceUnavailable: "cloud.serviceUnavailable"
        @unknown default: "cloud.unknown"
        }
    }

    private static func name(of error: ScriptAIError) -> String {
        switch error {
        case .modelUnavailable: "modelUnavailable"
        case .emptyResponse: "emptyResponse"
        case .tooLong: "tooLong"
        case .unsupportedLanguage: "unsupportedLanguage"
        case .unsupportedTranslation: "unsupportedTranslation"
        case .modelPreparing: "modelPreparing"
        case .wrongLanguage: "wrongLanguage"
        case .rateLimited: "rateLimited"
        case .timedOut: "timedOut"
        }
    }

    private static func name(of failure: AIPlanFailure) -> String {
        switch failure {
        case .deviceNotSupported: "deviceNotSupported"
        case .turnedOff: "turnedOff"
        case .modelPreparing: "modelPreparing"
        case .unsupportedLanguage(let language): "unsupportedLanguage(\(language.maximalIdentifier))"
        }
    }

    // MARK: - Writing it down

    /// The one line in Console.
    var line: String {
        let model = route.map { "\($0)" } ?? "none"
        let outcome = isFinal ? "told the creator" : "trying again"
        var line = """
            \(operation) failed on \(model) after \(String(format: "%.2f", seconds))s: \(reason) (\(outcome)) · \
            language=\(language ?? "auto") model=\(conditions.model) thermal=\(conditions.thermal) lowPower=\(conditions.lowPower) \
            freeMemory=\(conditions.freeMemoryMB)MB app=\(conditions.appState) device=\(conditions.device) iOS \(conditions.system)
            """
        if !detail.isEmpty { line += " · \(detail)" }
        return line
    }

    /// The same, as the keys of a crash report.
    var keys: [String: String] {
        [
            "operation": operation, "route": route.map { "\($0)" } ?? "none", "reason": reason, "detail": detail,
            "language": language ?? "auto", "seconds": String(format: "%.2f", seconds), "final": "\(isFinal)",
            "modelAvailability": conditions.model, "thermal": conditions.thermal, "lowPower": "\(conditions.lowPower)",
            "freeMemoryMB": "\(conditions.freeMemoryMB)", "appState": conditions.appState, "device": conditions.device,
            "system": conditions.system,
        ]
    }

    private static let logger = Logger(subsystem: "studio.cue", category: "ScriptAI")

    /// Into Console: an error when the creator was told, a notice when it was tried again.
    func log() {
        if isFinal {
            Self.logger.error("\(line, privacy: .public)")
        } else {
            Self.logger.notice("\(line, privacy: .public)")
        }
    }
}

extension AIFailureReport {
    /// Writes a failed attempt down: in Console, and as a crash report when the creator was told. A cancellation the creator asked for
    /// (the task itself was cancelled) isn't a failure and isn't written.
    @MainActor
    static func note(_ error: any Error, operation: String, route: AIModelRoute?, language: String?, seconds: Double, isFinal: Bool) {
        if error is CancellationError, Task.isCancelled { return }
        let (reason, detail) = reason(of: error)
        let report = AIFailureReport(
            operation: operation, route: route, reason: reason, detail: detail, language: language, seconds: seconds, isFinal: isFinal,
            conditions: .current(appState: appState)
        )
        report.log()
        if isFinal { TelemetryManager.record(report) }
    }

    @MainActor
    private static var appState: String {
        switch UIApplication.shared.applicationState {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }
}
