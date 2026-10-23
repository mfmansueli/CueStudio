//
//  QuickEditViewModel+Beats.swift
//  Cue Studio
//

import Foundation

/// Beats, for the music the creator brings from Files (Cue has no music library of its own): the beats are found on the iPhone
/// when the file comes in (`BeatDetector`, kept next to the file), show as ticks on the music track, and the playhead and the
/// handles stick to them (Snap to beats). Move cuts to the beats puts each cut on the nearest beat; Cut on the beats cuts the
/// video on every beat (or every second or fourth). Each is one undo step.
extension QuickEditViewModel {
    /// The beats of a music file, when they've been found (an empty list: the file has no steady beat).
    func beats(ofFile name: String) -> BeatTracker.Result? {
        if let cached = beatCache[name] { return cached }
        guard let stored = BeatStore.load(forSound: name) else { return nil }
        beatCache[name] = stored
        return stored
    }

    /// The beats of a music clip where they play in the edit; none for a sound effect or a sound taken out of the video.
    func musicBeats(of clip: MusicClip) -> [TimeInterval] {
        guard !clip.followsTheVideo, let found = beats(ofFile: clip.fileName) else { return [] }
        return BeatCuts.editedBeats(of: clip, beats: found.beats, editDuration: edit.editedDuration)
    }

    /// Every beat of the music in the edit, in order.
    var editedBeats: [TimeInterval] {
        Array(Set(edit.music.filter { !$0.isMuted }.flatMap(musicBeats(of:)))).sorted()
    }

    /// Finds the beats of the music files that don't have them yet, one file at a time, off the main thread.
    func findBeatsIfNeeded() {
        for clip in edit.music where !clip.followsTheVideo {
            let name = clip.fileName
            guard beats(ofFile: name) == nil, !findingBeats.contains(name) else { continue }
            findingBeats.insert(name)
            Task { [weak self] in
                let found = await BeatDetector.beats(inSoundAt: EditMediaFiles.url(for: name)) ?? BeatTracker.Result(beats: [], tempo: 0)
                BeatStore.save(found, forSound: name)
                guard let self else { return }
                beatCache[name] = found
                findingBeats.remove(name)
                beatsFound += 1
            }
        }
    }

    /// The picked music clip, when it's music from Files.
    private var pickedMusic: MusicClip? {
        guard let id = selectedMusicID else { return nil }
        return edit.music.first { $0.id == id && !$0.followsTheVideo }
    }

    /// The panel's subtitle: "Music · 112 BPM · 48 beats", or how finding them goes.
    var beatsSubtitle: String {
        guard let clip = pickedMusic else { return String(localized: "Music from Files") }
        if findingBeats.contains(clip.fileName) { return String(localized: "Finding the beats…") }
        guard let found = beats(ofFile: clip.fileName) else { return String(localized: "Music from Files") }
        guard !found.beats.isEmpty else { return String(localized: "No steady beat in this music") }
        return String(localized: "\(Int(found.tempo.rounded())) BPM · \(musicBeats(of: clip).count) beats in the video")
    }

    /// Whether the picked music has beats to work with.
    var hasBeats: Bool { pickedMusic.map { !musicBeats(of: $0).isEmpty } ?? !editedBeats.isEmpty }

    func setSnapsToBeats(_ snaps: Bool) {
        changeEdit { $0.snapsToBeats = snaps }
    }

    func moveCutsToBeats() {
        guard let moved = BeatCuts.movingCuts(of: edit.timeline, onto: editedBeats) else {
            toast.show(edit.timeline.segments.count > 1
                ? String(localized: "No cut is near a beat")
                : String(localized: "Split the video first, or use Cut on the beats"))
            return
        }
        commit(moved.timeline)
        toast.show(
            String(localized: "\(moved.moved) cuts on the beat"), action: undoAction
        )
    }

    func cutOnBeats() {
        guard let cut = BeatCuts.cutting(edit.timeline, onto: editedBeats, every: beatCutEvery) else {
            toast.show(String(localized: "No beat to cut on"))
            return
        }
        commit(cut.timeline)
        toast.show(
            String(localized: "\(cut.cuts) cuts on the beats"), action: undoAction
        )
    }
}
