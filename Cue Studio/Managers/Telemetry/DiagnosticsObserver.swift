//
//  DiagnosticsObserver.swift
//  Cue Studio
//

import Foundation
import MetricKit

/// Listens to MetricKit's diagnostics (delivered by the system, about once a day, for the past day): each freeze, CPU or
/// disk-write problem becomes a `DeviceDiagnosticReport` for `TelemetryManager`. Started with the telemetry, so tests and
/// previews never listen.
nonisolated final class DiagnosticsObserver: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = DiagnosticsObserver()

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let reports = payloads.flatMap(Self.reports(from:))
        guard !reports.isEmpty else { return }
        Task { @MainActor in reports.forEach(TelemetryManager.record) }
    }

    private static func reports(from payload: MXDiagnosticPayload) -> [DeviceDiagnosticReport] {
        var reports: [DeviceDiagnosticReport] = []
        for hang in payload.hangDiagnostics ?? [] {
            reports.append(DeviceDiagnosticReport(
                kind: .hang, amount: Int(hang.hangDuration.converted(to: .milliseconds).value),
                build: hang.metaData.applicationBuildVersion, system: hang.metaData.osVersion, callStack: hang.callStackTree.jsonRepresentation()
            ))
        }
        for cpu in payload.cpuExceptionDiagnostics ?? [] {
            reports.append(DeviceDiagnosticReport(
                kind: .cpu, amount: Int(cpu.totalCPUTime.converted(to: .milliseconds).value),
                build: cpu.metaData.applicationBuildVersion, system: cpu.metaData.osVersion, callStack: cpu.callStackTree.jsonRepresentation()
            ))
        }
        for disk in payload.diskWriteExceptionDiagnostics ?? [] {
            reports.append(DeviceDiagnosticReport(
                kind: .diskWrites, amount: Int(disk.totalWritesCaused.converted(to: .megabytes).value),
                build: disk.metaData.applicationBuildVersion, system: disk.metaData.osVersion, callStack: disk.callStackTree.jsonRepresentation()
            ))
        }
        return reports
    }
}
