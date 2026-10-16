//
//  DeviceDiagnosticReport.swift
//  Cue Studio
//

import Foundation

/// A problem the system measured on a creator's iPhone (MetricKit): the app's screen frozen for a while, the CPU kept busy,
/// or too much written to disk. What it was, how big, and the build and system; never anything the creator made.
/// Sent as a non-fatal report (`TelemetryManager.record(_:)`), so freezes in the field show up like crashes do.
nonisolated struct DeviceDiagnosticReport: Hashable, Sendable {
    enum Kind: String, Sendable {
        case hang, cpu, diskWrites
    }

    let kind: Kind
    /// Milliseconds frozen (a hang) or of CPU (cpu); megabytes written (disk writes).
    let amount: Int
    let build: String
    let system: String
    /// The system's call stack tree as JSON (addresses and binary names), cut to fit a report line.
    let callStack: String

    /// How much of the call stack goes with the report.
    static let callStackLimit = 8_000

    init(kind: Kind, amount: Int, build: String, system: String, callStack: Data?) {
        self.kind = kind
        self.amount = amount
        self.build = build
        self.system = system
        self.callStack = callStack.flatMap { String(bytes: $0.prefix(Self.callStackLimit), encoding: .utf8) } ?? ""
    }

    /// The report's issue: one per kind, so the console groups them.
    var domain: String { "MetricKit.\(kind.rawValue)" }

    var keys: [String: Any] {
        ["amount": amount, "build": build, "system": system]
    }
}
