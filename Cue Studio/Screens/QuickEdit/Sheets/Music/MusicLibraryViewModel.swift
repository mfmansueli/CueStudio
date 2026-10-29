//
//  MusicLibraryViewModel.swift
//  Cue Studio
//

import Foundation

/// The music library in "Add music or a sound": Cue's tracks found by name, style, use or mood and filtered (all, made to sit
/// under talking, one mood), each heard before it's added (a second tap or another track stops it; while its file is fetched
/// the row says so, which with the bundle's files is a blink), with what it covers of the video and its licence.
@Observable
final class MusicLibraryViewModel {
    var query = ""
    var filter: MusicLibraryFilter = .all
    /// The track whose details (what it covers, origin, terms, credit) are open.
    var detailed: CueTrack?
    /// The track whose file is being fetched to be heard.
    private(set) var preparing: CueTrack?
    /// The track being added.
    private(set) var adding: CueTrack?
    /// The track that couldn't be heard.
    private(set) var failed: CueTrack?
    /// The edit's length, for what a track covers.
    let editDuration: TimeInterval

    private let files: any MusicLibraryFiles
    private let previews: SoundPreviewing
    private let add: (CueTrack) async -> Bool
    @ObservationIgnored private var work: Task<Void, Never>?

    init(
        files: any MusicLibraryFiles, previews: SoundPreviewing, editDuration: TimeInterval, add: @escaping (CueTrack) async -> Bool
    ) {
        self.files = files
        self.previews = previews
        self.editDuration = editDuration
        self.add = add
    }

    /// The tracks the search and the filter leave, in the library's order.
    var tracks: [CueTrack] {
        CueTrack.allCases.filter { filter.includes($0) && $0.matches(query) }
    }

    static func previewKey(_ track: CueTrack) -> String { "library.\(track.rawValue)" }

    func isPlaying(_ track: CueTrack) -> Bool { previews.playingKey == Self.previewKey(track) }

    /// Plays the track from its start, or stops it when it's the one playing or being made.
    func togglePreview(_ track: CueTrack) {
        let wasOn = isPlaying(track) || preparing == track
        stop()
        guard !wasOn else { return }
        failed = nil
        preparing = track
        work = Task { [weak self, files] in
            do {
                let url = try await files.file(for: track)
                guard let self, !Task.isCancelled, preparing == track else { return }
                preparing = nil
                previews.play(url, key: Self.previewKey(track))
            } catch {
                guard let self, !Task.isCancelled, preparing == track else { return }
                preparing = nil
                failed = track
            }
        }
    }

    /// Stops what plays or is being made to play.
    func stop() {
        work?.cancel()
        work = nil
        preparing = nil
        previews.stop()
    }

    /// Adds the track at the playhead (or in place of the clip Replace asked for). Returns whether it went in.
    func add(_ track: CueTrack) async -> Bool {
        guard adding == nil else { return false }
        stop()
        adding = track
        defer { adding = nil }
        return await add(track)
    }

    /// "Covers the whole video" or "Covers 0:45 of 1:12": the track is cut at the video's end, or ends before it.
    func coverage(of track: CueTrack) -> String {
        guard track.duration < editDuration - 0.05 else { return String(localized: "Covers the whole video") }
        return String(localized: "Covers \(DurationText.clock(track.duration)) of \(DurationText.clock(editDuration))")
    }
}
