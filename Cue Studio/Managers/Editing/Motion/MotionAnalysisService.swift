//
//  MotionAnalysisService.swift
//  Cue Studio
//

import Foundation
import os

/// Analyzes the recordings the editor plays (`MotionAnalysis`), one at a time, in the background of the app: at a low priority,
/// only while Cue is open and the iPhone is cool. When Cue goes to the background or the iPhone gets hot, the analysis stops
/// where it is (what's done is kept next to the recording) and goes on by itself when Cue is back and the iPhone has cooled.
///
/// Face follow and stabilization read the analyses from their files (`MotionAnalysisStore`); this service only makes them and
/// says how far each one is, so the editor can show it and draw the preview again when one is ready (`completed`).
@MainActor
@Observable
final class MotionAnalysisService {
    /// Where each recording's analysis stands, by its file.
    private(set) var statuses: [URL: MotionAnalysisStatus] = [:]
    /// Bumped each time an analysis is ready: the editor draws the preview again.
    private(set) var completed = 0
    /// Why the analyses wait now, if they do.
    private(set) var pause: MotionAnalysisPause?

    private let analyzer: MotionAnalyzing
    private let thermalState: () -> ProcessInfo.ThermalState
    /// In the order they'll be analyzed; the urgent ones first.
    private var queue: [URL] = []
    private var running: URL?
    private var isActive = true
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Tells the running analysis to stop where it is (read on its own thread).
    @ObservationIgnored private let stopFlag = OSAllocatedUnfairLock(initialState: false)
    @ObservationIgnored private var thermalObserver: NSObjectProtocol?

    init(analyzer: MotionAnalyzing = MotionAnalyzer(), thermalState: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState }) {
        self.analyzer = analyzer
        self.thermalState = thermalState
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.conditionsChanged() }
        }
    }

    isolated deinit {
        if let thermalObserver { NotificationCenter.default.removeObserver(thermalObserver) }
    }

    /// Where the recording's analysis stands; nil when it was never asked for.
    func status(of recording: URL) -> MotionAnalysisStatus? {
        statuses[recording.standardizedFileURL]
    }

    /// Analyzes these recordings (a take and the other recordings of its montage) when they aren't yet. `urgent` puts them first
    /// (the editor is open on them).
    func request(_ recordings: [URL], urgent: Bool = true) {
        var added: [URL] = []
        for recording in recordings.map(\.standardizedFileURL) {
            if statuses[recording] == .ready || running == recording { continue }
            if MotionAnalysisStore.complete(forRecording: recording) != nil {
                statuses[recording] = .ready
                continue
            }
            queue.removeAll { $0 == recording }
            added.append(recording)
            if statuses[recording] == nil || statuses[recording] == .failed {
                let done = MotionAnalysisStore.load(forRecording: recording).flatMap { $0.isCurrent ? $0.progress : nil } ?? 0
                statuses[recording] = done > 0 ? .paused(pause ?? .background, done) : .waiting
            }
        }
        queue = urgent ? added + queue : queue + added
        pump()
    }

    /// Cue came to the front (`true`) or went to the background.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        conditionsChanged()
    }

    // MARK: - Running

    private func conditionsChanged() {
        pause = MotionAnalysisPause.reason(isActive: isActive, thermal: thermalState())
        if pause != nil {
            stopFlag.withLock { $0 = true }
            for (recording, status) in statuses {
                if case .waiting = status { statuses[recording] = .paused(pause ?? .background, 0) }
            }
        } else {
            for (recording, status) in statuses {
                if case .paused(_, let done) = status { statuses[recording] = done > 0 ? .analyzing(done) : .waiting }
            }
            pump()
        }
    }

    private func pump() {
        pause = MotionAnalysisPause.reason(isActive: isActive, thermal: thermalState())
        guard running == nil, pause == nil, !queue.isEmpty else { return }
        let recording = queue.removeFirst()
        running = recording
        stopFlag.withLock { $0 = false }
        let previous = MotionAnalysisStore.load(forRecording: recording)
        statuses[recording] = .analyzing(previous.flatMap { $0.isCurrent ? $0.progress : nil } ?? 0)
        let analyzer = analyzer, flag = stopFlag
        task = Task.detached(priority: .utility) { [weak self] in
            let result: MotionAnalysis?
            do {
                result = try await analyzer.analyze(
                    videoAt: recording, continuing: previous, shouldStop: { flag.withLock { $0 } },
                    checkpoint: { analysis in
                        MotionAnalysisStore.save(analysis, forRecording: recording)
                        Task { @MainActor in self?.progressed(recording, to: analysis.progress) }
                    }
                )
            } catch {
                result = nil
            }
            if let result { MotionAnalysisStore.save(result, forRecording: recording) }
            await self?.finished(recording, with: result)
        }
    }

    private func progressed(_ recording: URL, to progress: Double) {
        guard running == recording, case .analyzing = statuses[recording] else { return }
        statuses[recording] = .analyzing(progress)
    }

    private func finished(_ recording: URL, with result: MotionAnalysis?) {
        running = nil
        task = nil
        if let result {
            if result.isComplete {
                statuses[recording] = .ready
                completed += 1
            } else {
                // Stopped: back to the front of the line, waiting for Cue or the iPhone.
                statuses[recording] = .paused(pause ?? .background, result.progress)
                queue.insert(recording, at: 0)
            }
        } else {
            statuses[recording] = .failed
        }
        pump()
    }
}
