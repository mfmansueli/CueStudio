//
//  QuickEditViewModel+Music.swift
//  Cue Studio
//

import Foundation

/// Music: the creator's own sound files (from Files, copied into the app) under the video. Added at
/// the playhead for as long as the file or the edit lasts, then moved or trimmed on the music
/// track, with its volume, fades, mute and whether it goes down while someone speaks. Music is
/// placed on the edit's own seconds: cutting something before it doesn't move it. Every change is
/// an undo step; a slider is one.
extension QuickEditViewModel {
    /// New music goes in at 40%, under the voice.
    static let newMusicVolume: Double = 0.4

    var musicBars: [LayerBar] {
        edit.music.compactMap { clip in
            guard let span = clip.span(inEditOf: edit.editedDuration) else { return nil }
            return LayerBar(id: clip.id, kind: .music, span: span, title: clip.title, isSelected: clip.id == selectedMusicID)
        }
    }

    /// Copies the sound file in and adds it at the playhead.
    func importMusic(from url: URL) async {
        guard isReady, !isImportingMusic else { return }
        isImportingMusic = true
        defer { isImportingMusic = false }
        do {
            let imported = try await mediaImporter.importAudio(from: url)
            guard !isClosed else {
                EditMediaFiles.remove([imported.fileName])
                return
            }
            addMusic(imported)
        } catch {
            noteFailure(error, "importMusic")
            toast.show(EditorErrorMessage.text(for: error, otherwise: String(localized: "Can't add this file")))
        }
    }

    /// Adds a sound file at the playhead, in the free room around it (see `MusicPlacement`), for as
    /// long as the file or that room lasts. When "Replace" asked for the file, it takes the place
    /// of that clip instead.
    func addMusic(_ imported: ImportedAudio) {
        importedFiles.insert(imported.fileName)
        if let replacing = musicReplacementID {
            replaceMusic(replacing, with: imported)
            return
        }
        // Sound effects and extracted sounds can play over music: only music takes room.
        let occupied = edit.music.filter(\.takesMusicRoom).compactMap { $0.span(inEditOf: edit.editedDuration) }
        guard let slot = MusicPlacement.slot(playhead: player.currentTime, editDuration: edit.editedDuration, occupied: occupied) else {
            discard(imported)
            toast.show(String(localized: "No room · Move the playhead"))
            return
        }
        let length = min(imported.duration, slot.duration)
        guard length >= MusicClip.minimumDuration else {
            discard(imported)
            toast.show(String(localized: "Can't add this file"))
            return
        }
        var clip = MusicClip(
            fileName: imported.fileName, title: imported.title, fileDuration: imported.duration, start: slot.start, length: length
        )
        clip.volume = Self.newMusicVolume
        change { $0.music = ($0.music ?? []) + [clip] }
        findBeatsIfNeeded()
        selectedMusicID = clip.id
        player.pause()
        player.seek(to: slot.start)
        sayUndoable(String(localized: "Music added at \(DurationText.editor(slot.start)) · 40%"))
    }

    /// "Replace": the clip keeps its place, volume and fades, and plays the new file from its
    /// start (shortened when the file is shorter).
    private func replaceMusic(_ id: UUID, with imported: ImportedAudio) {
        musicReplacementID = nil
        guard edit.music.contains(where: { $0.id == id }) else {
            discard(imported)
            return
        }
        guard imported.duration >= MusicClip.minimumDuration else {
            discard(imported)
            toast.show(String(localized: "Can't add this file"))
            return
        }
        updateMusic(id) { clip in
            clip.fileName = imported.fileName
            clip.title = imported.title
            clip.fileDuration = imported.duration
            clip.offset = 0
            clip.length = min(clip.length, imported.duration)
        }
        selectedMusicID = id
        findBeatsIfNeeded()
        toast.show(String(localized: "Music replaced"))
    }

    // MARK: - Sound effects

    /// Adds a sound effect at the playhead (over music or another effect), at 80%, never going down under the voice. The file is
    /// made by Cue (`SoundEffectSynth`) and linked into the edit's media.
    func addSoundEffect(_ effect: SoundEffect) {
        guard isReady else { return }
        do {
            let file = try SoundEffectSynth.file(for: effect)
            let name = try EditMediaFiles.link(file)
            importedFiles.insert(name)
            let duration = SoundEffectSynth.duration(ofFile: file) ?? Double(SoundEffectSynth.samples(for: effect).count) / SoundEffectSynth.sampleRate
            let total = edit.editedDuration
            let start = min(player.currentTime, max(0, total - MusicClip.minimumDuration))
            let length = min(duration, total - start)
            guard length >= MusicClip.minimumDuration else {
                EditMediaFiles.remove([name])
                importedFiles.remove(name)
                toast.show(String(localized: "No room · Move the playhead"))
                return
            }
            var clip = MusicClip(fileName: name, title: effect.label, fileDuration: duration, start: start, length: length)
            clip.effect = effect
            clip.volume = 0.8
            clip.fadeIn = 0
            clip.fadeOut = 0
            clip.ducksUnderVoice = false
            change { $0.music = ($0.music ?? []) + [clip] }
            selectedMusicID = clip.id
            player.pause()
            player.seek(to: start)
            sayUndoable(String(localized: "\(effect.label) added at \(DurationText.editor(start))"))
        } catch {
            noteFailure(error, "addSound")
            toast.show(String(localized: "Can't add this sound"))
        }
    }

    private func discard(_ imported: ImportedAudio) {
        EditMediaFiles.remove([imported.fileName])
        importedFiles.remove(imported.fileName)
    }

    func deleteMusic(_ id: UUID) {
        change { $0.music?.removeAll { $0.id == id } }
        if selectedMusicID == id { selectedMusicID = nil }
    }

    func setMusicFadeIn(_ id: UUID, _ seconds: TimeInterval) {
        updateMusic(id) { $0.fadeIn = min(max(seconds, MusicClip.fadeRange.lowerBound), MusicClip.fadeRange.upperBound) }
    }

    func setMusicFadeOut(_ id: UUID, _ seconds: TimeInterval) {
        updateMusic(id) { $0.fadeOut = min(max(seconds, MusicClip.fadeRange.lowerBound), MusicClip.fadeRange.upperBound) }
    }

    func setMusicDucks(_ id: UUID, _ ducks: Bool) {
        updateMusic(id) { $0.ducksUnderVoice = ducks }
    }

    /// Moves a clip so it starts at `start` (edited seconds), keeping its length, within the edit.
    func moveMusic(_ id: UUID, toStart start: TimeInterval) {
        guard let clip = edit.music.first(where: { $0.id == id }) else { return }
        let latest = max(0, edit.editedDuration - min(clip.length, edit.editedDuration))
        updateMusic(id) { $0.start = min(max(0, start), latest) }
    }

    /// Moves one end of a clip to `time` (edited seconds). The start takes the file along: moving
    /// it later skips the file's beginning, and back brings it again.
    func resizeMusic(_ id: UUID, edge: LayerEdge, to time: TimeInterval) {
        guard let clip = edit.music.first(where: { $0.id == id }) else { return }
        let shortest = MusicClip.minimumDuration
        switch edge {
        case .start:
            let end = clip.start + clip.length
            // No earlier than the file's own start or the edit's.
            let earliest = max(0, clip.start - clip.offset)
            let start = min(max(time, earliest), end - shortest)
            updateMusic(id) { music in
                music.offset += start - music.start
                music.start = start
                music.length = end - start
            }
        case .end:
            let longest = min(clip.fileDuration - clip.offset, edit.editedDuration - clip.start)
            let length = min(max(time - clip.start, shortest), max(shortest, longest))
            updateMusic(id) { $0.length = length }
        }
    }

    /// Changes a music clip (one undo step, or part of the gesture's).
    func updateMusic(_ id: UUID, _ update: (inout MusicClip) -> Void) {
        change { snapshot in
            guard var music = snapshot.music, let index = music.firstIndex(where: { $0.id == id }) else { return }
            update(&music[index])
            snapshot.music = music
        }
    }
}
