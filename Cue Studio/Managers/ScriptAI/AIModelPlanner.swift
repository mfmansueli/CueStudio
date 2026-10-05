//
//  AIModelPlanner.swift
//  Cue Studio
//

import Foundation

/// Chooses the model for a request from what the models can do *in the request's languages*. Apple
/// Intelligence being available says nothing about a language: Cue's Hindi, Indonesian, Arabic and
/// Thai, for one, aren't among the languages the device model writes. A translation needs both the
/// source and the target.
///
/// Private Cloud Compute is only a candidate when the app offers it (`AIModelCapabilities.cloudStatus`
/// is nil without the entitlement) and its own language list covers the request.
nonisolated struct AIModelPlanner: Sendable {
    let capabilities: AIModelCapabilities

    func plan(_ task: AIModelRoute.Task, languages: [Locale]) async -> Result<AIPlan, AIPlanFailure> {
        let device = capabilities.deviceStatus
        let deviceMissing = languages.first { !capabilities.deviceSupports($0) }
        let deviceUsable = device == .available && deviceMissing == nil

        let cloud = capabilities.cloudStatus
        var cloudMissing: Locale?
        if cloud == .available {
            for locale in languages where !(await capabilities.cloudSupports(locale)) {
                cloudMissing = locale
                break
            }
        }
        let cloudUsable = cloud == .available && cloudMissing == nil

        let usable = Set([deviceUsable ? AIModelRoute.onDevice : nil, cloudUsable ? .privateCloud : nil].compactMap { $0 })
        if let route = AIModelRoute.choose(for: task, onDeviceAvailable: deviceUsable, privateCloudAvailable: cloudUsable) {
            return .success(AIPlan(route: route, usable: usable))
        }
        return .failure(Self.failure(device: device, deviceMissing: deviceMissing, cloud: cloud, cloudMissing: cloudMissing))
    }

    /// What can be told at once, without waiting for a request: why no model can take `languages`, or
    /// nil when the device model can. Private Cloud Compute's own language list is only asked in
    /// `plan`, so while the cloud is available this doesn't rule anything out.
    func quickFailure(languages: [Locale]) -> AIPlanFailure? {
        let device = capabilities.deviceStatus
        let deviceMissing = languages.first { !capabilities.deviceSupports($0) }
        if device == .available, deviceMissing == nil { return nil }
        if capabilities.cloudStatus == .available { return nil }
        return Self.failure(device: device, deviceMissing: deviceMissing, cloud: capabilities.cloudStatus, cloudMissing: nil)
    }

    /// The reason to tell: a device that can't run Apple Intelligence, or has it off, says so whatever
    /// the language; otherwise a language no available model writes; otherwise the model is getting ready.
    private static func failure(
        device: AIModelStatus, deviceMissing: Locale?, cloud: AIModelStatus?, cloudMissing: Locale?
    ) -> AIPlanFailure {
        switch device {
        case .deviceNotEligible: return .deviceNotSupported
        case .turnedOff: return .turnedOff
        case .available, .preparing, .quotaReached:
            // Waiting won't help a language the model doesn't write.
            if let missing = deviceMissing ?? cloudMissing { return .unsupportedLanguage(missing.language) }
            return .modelPreparing
        }
    }
}
