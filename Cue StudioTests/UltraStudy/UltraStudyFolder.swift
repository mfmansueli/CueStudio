//
//  UltraStudyFolder.swift
//  Cue StudioTests
//

import Foundation

/// Where the Ultra study reads its jobs and saves what they wrote (`TEST_RUNNER_CUE_ULTRA_STUDY`, a folder the Simulator can reach, so not on
/// the Desktop), and which jobs are still to write. `UltraStudyTests` runs only when the folder is set.
nonisolated enum UltraStudyFolder {
    static let url = ProcessInfo.processInfo.environment["CUE_ULTRA_STUDY"].map { URL(filePath: $0, directoryHint: .isDirectory) }
    /// Jobs written at the same time (`CUE_ULTRA_STUDY_PARALLEL`, 6 unless set).
    static let width = max(1, Int(ProcessInfo.processInfo.environment["CUE_ULTRA_STUDY_PARALLEL"] ?? "") ?? 6)

    /// The jobs not saved yet, in the file's order.
    static let pending: [UltraStudyJob] = {
        guard let url, let data = try? Data(contentsOf: url.appending(path: "jobs.json")),
              let jobs = try? JSONDecoder().decode([UltraStudyJob].self, from: data) else { return [] }
        return jobs.filter { !FileManager.default.fileExists(atPath: output(for: $0).path) }
    }()

    /// One batch of `width` jobs per test case.
    static let batches = Array(0..<max(1, (pending.count + width - 1) / width))

    static func jobs(in batch: Int) -> [UltraStudyJob] {
        Array(pending.dropFirst(batch * width).prefix(width))
    }

    static func output(for job: UltraStudyJob) -> URL {
        (url ?? URL.temporaryDirectory).appending(path: "out/\(job.id).json")
    }

    /// A job the API failed after its tries: kept for a look, and written again on the next run.
    static func failure(for job: UltraStudyJob) -> URL {
        (url ?? URL.temporaryDirectory).appending(path: "failed/\(job.id).json")
    }
}
