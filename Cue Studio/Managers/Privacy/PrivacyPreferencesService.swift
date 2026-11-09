//
//  PrivacyPreferencesService.swift
//  Cue Studio
//

import Foundation

/// The two switches of Settings › Privacy & AI data. "Apple Intelligence" is the master switch of every Apple Intelligence feature
/// (`ScriptWriting.isEnabled`). "Help improve Cue" is the one control of the usage data and crash reports (owner, 09/11/2026): off until the
/// creator turns it on, applied to the telemetry at launch and on every change; turned off, what waits on this iPhone to be sent goes too.
@MainActor
@Observable
final class PrivacyPreferencesService {
    /// The stored key keeps its original name so an existing opt-out remains in effect after enabling PCC.
    var usesOnDeviceAI: Bool {
        didSet {
            defaults.set(usesOnDeviceAI, forKey: DefaultsKey.onDeviceAI)
            writer.isEnabled = usesOnDeviceAI
        }
    }

    var helpsImproveCue: Bool {
        didSet {
            defaults.set(helpsImproveCue, forKey: DefaultsKey.helpImproveCue)
            telemetry.setCollecting(helpsImproveCue)
            if oldValue, !helpsImproveCue { telemetry.discardUnsent() }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let writer: ScriptWriting
    @ObservationIgnored private let telemetry: TelemetryCollecting

    init(defaults: UserDefaults = .standard, writer: ScriptWriting, telemetry: TelemetryCollecting = FirebaseTelemetry()) {
        self.defaults = defaults
        self.writer = writer
        self.telemetry = telemetry
        let usesAI = defaults.object(forKey: DefaultsKey.onDeviceAI) as? Bool ?? true
        usesOnDeviceAI = usesAI
        let helps = Self.helpsImprove(in: defaults)
        helpsImproveCue = helps
        writer.isEnabled = usesAI
        telemetry.setCollecting(helps)
    }

    /// The stored choice, off until the creator turns it on; read before the services exist too (`TelemetryManager.start`).
    nonisolated static func helpsImprove(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: DefaultsKey.helpImproveCue) as? Bool ?? false
    }
}
