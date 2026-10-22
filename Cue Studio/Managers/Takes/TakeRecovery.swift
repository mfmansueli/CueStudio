//
//  TakeRecovery.swift
//  Cue Studio
//

import AVFoundation

/// Gives back the takes a past session left in the temporary folder. The camera records there (`take-<UUID>.mov`,
/// `CameraManager`) and the library moves the file in once the take ends, so one still there after a relaunch was never
/// filed: Cue stopped mid-take (a crash, or iOS ending it in the background; the movie output writes fragments, so the
/// file plays up to the last one) or the library couldn't take it in. Run once a launch, a while after it: a recording
/// of this launch (one may be under way) is never touched.
nonisolated enum TakeRecovery {
    /// What the camera names its recordings.
    static let prefix = "take-"
    /// Shorter than this is a tap on Record and nothing more.
    static let minimumDuration: TimeInterval = 0.5

    /// What becomes of a leftover recording.
    enum Verdict: Equatable, Sendable {
        /// A video that plays, this long: it becomes a take.
        case recover(duration: TimeInterval)
        /// Nothing anyone could play: its space is given back.
        case remove
        /// Can't be read now (the iPhone not unlocked since it started, like the library): left for a later launch.
        case leave
    }

    /// The recordings past sessions left, oldest first: the camera's names, last written before this launch.
    static func leftovers(files: [String: Date], launchedAt: Date) -> [String] {
        files.filter { $0.key.hasPrefix(prefix) && $0.key.hasSuffix(".mov") && $0.value < launchedAt }
            .sorted { $0.value < $1.value }
            .map(\.key)
    }

    static func verdict(hasVideo: Bool, duration: TimeInterval) -> Verdict {
        guard hasVideo, duration.isFinite, duration >= minimumDuration else { return .remove }
        return .recover(duration: duration)
    }

    /// Files each leftover as a freestyle take (the script it was read from isn't known) with the creator's camera
    /// settings, and removes the ones that can't be played. Returns how many came back.
    @MainActor
    @discardableResult
    static func recover(
        into takes: TakeLibraryService,
        camera: CameraSettings,
        launchedAt: Date,
        folder: URL = .temporaryDirectory,
        inspect: (URL) async -> Verdict = { await TakeRecovery.verdict(for: $0) }
    ) async -> Int {
        let files = await listing(of: folder)
        var recovered = 0
        for name in leftovers(files: files, launchedAt: launchedAt) {
            let url = folder.appending(path: name)
            switch await inspect(url) {
            case .recover(let duration):
                // A library that can't take it in now leaves the file where it is, for the next launch.
                if (try? takes.addTake(fileAt: url, duration: duration, script: nil, camera: camera)) != nil { recovered += 1 }
            case .remove:
                try? FileManager.default.removeItem(at: url)
            case .leave:
                break
            }
        }
        return recovered
    }

    /// "Delete my Cue data": the recordings past sessions left, which would otherwise come back as takes at the next launch.
    /// Never during a recording (the eraser is in Settings).
    static func removeLeftovers(folder: URL = .temporaryDirectory) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        for name in names where name.hasPrefix(prefix) && name.hasSuffix(".mov") {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }

    /// Whether the recording plays and for how long, read off the main actor.
    @concurrent
    static func verdict(for url: URL) async -> Verdict {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .leave }
        try? handle.close()
        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration))?.seconds ?? 0
        let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
        return verdict(hasVideo: !videoTracks.isEmpty, duration: duration)
    }

    @concurrent
    private static func listing(of folder: URL) async -> [String: Date] {
        EditStorageCleaner.modified(in: folder)
    }
}
