//
//  TimelineWaveforms.swift
//  Cue Studio
//

import Foundation

/// The waveform of each recording the timeline shows, read once in the background and kept while
/// the editor is open. Says when one arrives so the timeline draws it.
@MainActor
final class TimelineWaveforms {
    /// Called when a recording's levels are in.
    var onChange: (() -> Void)?

    private var levels: [URL: [Float]] = [:]
    private var reading: Set<URL> = []
    private var tasks: [Task<Void, Never>] = []

    /// The levels of `url`, one per `WaveformReader.interval`; nil until read (then read now).
    func levels(for url: URL) -> [Float]? {
        if let known = levels[url] { return known }
        guard !reading.contains(url) else { return nil }
        reading.insert(url)
        tasks.append(Task { [weak self] in
            let read = (try? await WaveformReader.levels(ofVideoAt: url)) ?? []
            guard !Task.isCancelled, let self else { return }
            self.levels[url] = read
            self.reading.remove(url)
            self.onChange?()
        })
        return nil
    }

    func cancel() {
        tasks.forEach { $0.cancel() }
        tasks = []
    }
}
