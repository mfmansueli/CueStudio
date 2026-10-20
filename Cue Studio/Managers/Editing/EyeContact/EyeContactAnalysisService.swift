//
//  EyeContactAnalysisService.swift
//  Cue Studio
//

import Foundation
import os

/// Analyzes the recordings an edit with Eye Contact plays (`EyeContactAnalysis`), one at a time, in the background of the app: at
/// a low priority, only while Cue is open and the iPhone is cool. It starts with the stretch the preview shows (`focus`), so the
/// creator sees the effect within seconds, then goes on to the rest; when Cue goes to the background or the iPhone gets hot it stops
/// where it is (what's done is kept next to the recording) and goes on by itself later. Moving the playhead somewhere not analyzed
/// yet moves the work there (`refocus`).
///
/// The preview reads the analyses from their files (`EyeContactAnalysisStore`); this service only makes them, says how far each one
/// is, and bumps `updated` when the stretch the preview shows becomes ready and when a recording is done, so the editor can draw
/// the preview again.
@MainActor
@Observable
final class EyeContactAnalysisService {
    /// Where each recording's analysis stands, by its file.
    private(set) var statuses: [URL: MotionAnalysisStatus] = [:]
    /// Bumped each time more is ready to draw (the stretch the preview shows, or a whole recording).
    private(set) var updated = 0
    /// Why the analyses wait now, if they do.
    private(set) var pause: MotionAnalysisPause?
    /// Whether the model and the GPU passes run on this iPhone: nil until checked (`warmUp`), off the main thread.
    private(set) var engineWorks: Bool?

    private let analyzer: EyeContactAnalyzing
    private let thermalState: () -> ProcessInfo.ThermalState
    /// In the order they'll be analyzed; the urgent ones first.
    private var queue: [URL] = []
    /// Where each recording's preview is, in its own seconds.
    private var focuses: [URL: TimeInterval] = [:]
    private var running: URL?
    /// The running recording's focus stretch was ready already when it was last reported.
    private var focusReported = false
    private var isActive = true
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Tells the running analysis to stop where it is (read on its own thread).
    @ObservationIgnored private let stopFlag = OSAllocatedUnfairLock(initialState: false)
    @ObservationIgnored private var thermalObserver: NSObjectProtocol?

    init(
        analyzer: EyeContactAnalyzing = EyeContactAnalyzer(),
        thermalState: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState }
    ) {
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

    /// Loads the face mesh once, in the background, before the first frame needs it (a frame would otherwise wait for it), and finds
    /// out whether it works here.
    func warmUp() {
        guard engineWorks == nil else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            let works = FaceMeshModel.shared.isAvailable
            await self?.engineChecked(works)
        }
    }

    private func engineChecked(_ works: Bool) {
        engineWorks = works
    }

    /// Where the recording's analysis stands; nil when it was never asked for.
    func status(of recording: URL) -> MotionAnalysisStatus? {
        statuses[recording.standardizedFileURL]
    }

    /// Analyzes these recordings when they aren't yet, each from its `focus` (seconds of that recording) when one is given. `urgent`
    /// puts them first (the editor is open on them).
    func request(_ recordings: [URL], focus: [URL: TimeInterval] = [:], urgent: Bool = true) {
        var added: [URL] = []
        for (given, time) in focus { focuses[given.standardizedFileURL] = time }
        for recording in recordings.map(\.standardizedFileURL) {
            if running == recording {
                // Turned off and on again while it was stopping: it goes on from where it stops (`finished` puts it back in line).
                if statuses[recording] == nil {
                    let done = EyeContactAnalysisStore.load(forRecording: recording)?.progress ?? 0
                    statuses[recording] = pause.map { .paused($0, done) } ?? .analyzing(done)
                }
                continue
            }
            let kept = EyeContactAnalysisStore.load(forRecording: recording)
            if kept?.isComplete == true {
                statuses[recording] = .ready
                continue
            }
            queue.removeAll { $0 == recording }
            added.append(recording)
            if statuses[recording] == nil || statuses[recording] == .failed || statuses[recording] == .ready {
                let done = kept?.progress ?? 0
                statuses[recording] = pause.map { .paused($0, done) } ?? (done > 0 ? .analyzing(done) : .waiting)
            }
        }
        queue = urgent ? added + queue : queue + added
        pump()
    }

    /// The preview moved to `time` of `recording`: when that stretch isn't analyzed yet, the work moves there (what was done stays).
    func refocus(_ recording: URL, at time: TimeInterval) {
        let recording = recording.standardizedFileURL
        focuses[recording] = time
        let kept = EyeContactAnalysisStore.load(forRecording: recording)
        guard statuses[recording] != .ready, !(kept?.covers(Self.focusSpan(at: time)) ?? false) else { return }
        if running == recording {
            // It starts again from there, keeping what it has.
            stopFlag.withLock { $0 = true }
        } else if queue.contains(recording) {
            queue.removeAll { $0 == recording }
            queue.insert(recording, at: 0)
        }
    }

    /// Stops analyzing these recordings (Eye Contact was turned off): the one running stops where it is, keeping what it did.
    func cancel(_ recordings: [URL]) {
        let recordings = Set(recordings.map(\.standardizedFileURL))
        queue.removeAll { recordings.contains($0) }
        for recording in recordings where statuses[recording] != .ready { statuses[recording] = nil }
        if let running, recordings.contains(running) { stopFlag.withLock { $0 = true } }
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
        if let pause {
            stopFlag.withLock { $0 = true }
            for (recording, status) in statuses {
                if case .waiting = status { statuses[recording] = .paused(pause, 0) }
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
        let previous = EyeContactAnalysisStore.load(forRecording: recording)
        let focus = focuses[recording]
        focusReported = focus.map { time in previous?.covers(Self.focusSpan(at: time)) ?? false } ?? true
        statuses[recording] = .analyzing(previous?.progress ?? 0)
        let analyzer = analyzer, flag = stopFlag
        task = Task.detached(priority: .utility) { [weak self] in
            let result: EyeContactAnalysis?
            do {
                result = try await analyzer.analyze(
                    videoAt: recording, continuing: previous, focus: focus, shouldStop: { flag.withLock { $0 } },
                    checkpoint: { analysis in
                        EyeContactAnalysisStore.save(analysis, forRecording: recording)
                        let ready = focus.map { analysis.covers(Self.focusSpan(at: $0)) } ?? false
                        Task { @MainActor in self?.progressed(recording, to: analysis.progress, focusReady: ready) }
                    }
                )
            } catch {
                result = nil
            }
            if let result {
                EyeContactAnalysisStore.save(result, forRecording: recording)
                // The decisions are worked out here, off the main thread, so the panel and the preview find them ready.
                if result.isComplete { _ = EyeContactAnalysisStore.plan(forRecording: recording) }
            }
            await self?.finished(recording, with: result)
        }
    }

    /// The stretch around the preview's moment that must be ready before it's worth drawing again.
    nonisolated static func focusSpan(at time: TimeInterval) -> TimeSpan {
        TimeSpan(start: time - EyeContactAnalyzer.focusBefore, end: time + 3)
    }

    private func progressed(_ recording: URL, to progress: Double, focusReady: Bool) {
        guard running == recording, case .analyzing = statuses[recording] else { return }
        statuses[recording] = .analyzing(progress)
        if focusReady, !focusReported {
            focusReported = true
            updated += 1
        }
    }

    private func finished(_ recording: URL, with result: EyeContactAnalysis?) {
        running = nil
        task = nil
        if let result {
            if result.isComplete {
                statuses[recording] = .ready
                updated += 1
            } else if statuses[recording] != nil {
                // Stopped for the heat, the background or a new focus: back to the front of the line.
                statuses[recording] = pause.map { .paused($0, result.progress) } ?? .analyzing(result.progress)
                queue.insert(recording, at: 0)
            }
        } else {
            statuses[recording] = .failed
        }
        pump()
    }
}
