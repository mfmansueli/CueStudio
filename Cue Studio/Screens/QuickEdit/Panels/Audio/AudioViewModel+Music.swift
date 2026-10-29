//
//  AudioViewModel+Music.swift
//  Cue Studio
//

import Foundation

/// Music: Cue's library tracks or the creator's own sound files (from Files, copied into the app) under the video. Added at
/// the playhead for as long as the file or the edit lasts, then moved or trimmed on the music
/// track, with its volume, fades, mute and whether it goes down while someone speaks. Music is
/// placed on the edit's own seconds: cutting something before it doesn't move it. Every change is
/// an undo step; a slider is one.
extension AudioViewModel {
    /// New music goes in at 40%, under the voice.
    static let newMusicVolume: Double = 0.4

    var musicBars: [LayerBar] {
        edit.music.compactMap { clip in
            guard let span = clip.span(inEditOf: edit.editedDuration) else { return nil }
            return LayerBar(id: clip.id, kind: .music, span: span, title: clip.title, isSelected: clip.id == selectedMusicID)
        }
    }

    /// Copies the sound file in and adds it at the playhead, or puts it in the clip "Replace" asked for: what the sheet was opened
    /// for is kept from the start, so closing it while the file copies never turns a Replace into an Add.
    func importMusic(from url: URL) async {
        guard isReady, !isImportingMusic else { return }
        let replacing = musicReplacementID
        isImportingMusic = true
        defer { isImportingMusic = false }
        do {
            let imported = try await importer.importAudio(from: url)
            guard !isClosed else {
                EditMediaFiles.remove([imported.fileName])
                return
            }
            addMusic(imported, replacing: replacing)
        } catch {
            noteFailure(error, "importMusic")
            toast.show(EditorErrorMessage.text(for: error, otherwise: String(localized: "Can't add this file")), kind: .problem)
        }
    }

    /// The music library's sheet model: its previews play through the same player as the effects'.
    func makeMusicLibrary() -> MusicLibraryViewModel {
        MusicLibraryViewModel(files: musicFiles, previews: soundPreviews, editDuration: edit.editedDuration) { [weak self] track in
            await self?.addLibraryTrack(track) ?? false
        }
    }

    /// Adds a library track at the playhead, or puts it in the clip "Replace" asked for, as a file from Files: its file
    /// (`musicFiles`, the app's bundle) is linked into the edit's media, and its beats are the score's, from the library's
    /// manifest (none are looked for). The clip keeps which track it is, so its origin and licence stay with the edit. Returns
    /// whether it went in.
    func addLibraryTrack(_ track: CueTrack) async -> Bool {
        guard isReady, !isImportingMusic else { return false }
        let replacing = musicReplacementID
        isImportingMusic = true
        defer { isImportingMusic = false }
        do {
            let file = try await musicFiles.file(for: track)
            guard !isClosed else { return false }
            let name = try EditMediaFiles.link(file)
            BeatStore.save(BeatTracker.Result(beats: track.beats, tempo: track.tempo), forSound: name)
            addMusic(ImportedAudio(fileName: name, title: track.title, duration: track.duration, libraryTrack: track), replacing: replacing)
            return edit.music.contains { $0.fileName == name }
        } catch is CancellationError {
            return false
        } catch {
            noteFailure(error, "addLibraryTrack")
            toast.show(String(localized: "Can't add this track"), kind: .problem)
            return false
        }
    }

    /// Adds a sound file at the playhead, in the free room around it (see `MusicPlacement`), for as
    /// long as the file or that room lasts. When "Replace" asked for the file (`replacing`, by default the clip it asks for
    /// now), it takes the place of that clip instead.
    func addMusic(_ imported: ImportedAudio, replacing: UUID?? = nil) {
        importedFiles.insert(imported.fileName)
        if let replacing = replacing ?? musicReplacementID {
            replaceMusic(replacing, with: imported)
            return
        }
        // Sound effects and extracted sounds can play over music: only music takes room.
        let occupied = edit.music.filter(\.takesMusicRoom).compactMap { $0.span(inEditOf: edit.editedDuration) }
        guard let slot = MusicPlacement.slot(playhead: player.currentTime, editDuration: edit.editedDuration, occupied: occupied) else {
            discard(imported)
            toast.show(String(localized: "No room · Move the playhead"), kind: .problem)
            return
        }
        let length = min(imported.duration, slot.duration)
        guard length >= MusicClip.minimumDuration else {
            discard(imported)
            toast.show(String(localized: "Can't add this file"), kind: .problem)
            return
        }
        var clip = MusicClip(
            fileName: imported.fileName, title: imported.title, fileDuration: imported.duration, start: slot.start, length: length
        )
        clip.volume = Self.newMusicVolume
        clip.duck = .standard
        clip.libraryTrack = imported.libraryTrack
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
            // The clip went meanwhile (Undo, Delete): nothing to replace, and nothing added in its stead.
            discard(imported)
            toast.show(String(localized: "The music clip is gone · Nothing replaced"), kind: .problem)
            return
        }
        guard imported.duration >= MusicClip.minimumDuration else {
            discard(imported)
            toast.show(String(localized: "Can't add this file"), kind: .problem)
            return
        }
        updateMusic(id) { clip in
            clip.fileName = imported.fileName
            clip.title = imported.title
            clip.fileDuration = imported.duration
            clip.libraryTrack = imported.libraryTrack
            clip.offset = 0
            clip.length = min(clip.length, imported.duration)
        }
        selectedMusicID = id
        findBeatsIfNeeded()
        sayUndoable(String(localized: "Music replaced"))
    }

    // MARK: - Sound effects

    /// Adds a sound effect at the playhead (over music or another effect), at 80%, never going down under the voice. Its file
    /// (`SoundEffectFiles`: a recording in the bundle or one Cue synthesizes) is linked into the edit's media.
    func addSoundEffect(_ effect: SoundEffect) {
        guard isReady else { return }
        do {
            let file = try SoundEffectFiles.file(for: effect)
            let name = try EditMediaFiles.link(file)
            importedFiles.insert(name)
            let duration = SoundEffectFiles.duration(ofFile: file) ?? 0
            let total = edit.editedDuration
            let start = min(player.currentTime, max(0, total - MusicClip.minimumDuration))
            let length = min(duration, total - start)
            guard length >= MusicClip.minimumDuration else {
                EditMediaFiles.remove([name])
                importedFiles.remove(name)
                toast.show(String(localized: "No room · Move the playhead"), kind: .problem)
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
            toast.show(String(localized: "Can't add this sound"), kind: .problem)
        }
    }

    private func discard(_ imported: ImportedAudio) {
        EditMediaFiles.remove([imported.fileName])
        importedFiles.remove(imported.fileName)
    }

    /// Takes a music clip, sound effect or extracted sound off the track, said with Undo like every other delete (its file stays
    /// for Undo until the editor closes).
    func deleteMusic(_ id: UUID) {
        guard let clip = edit.music.first(where: { $0.id == id }) else { return }
        change { $0.music?.removeAll { $0.id == id } }
        if selectedMusicID == id { selectedMusicID = nil }
        Haptics.delete()
        sayUndoable(clip.followsTheVideo ? String(localized: "Sound deleted") : String(localized: "Music deleted"))
    }

    func setMusicFadeIn(_ id: UUID, _ seconds: TimeInterval) {
        updateMusic(id) { $0.fadeIn = min(max(seconds, MusicClip.fadeRange.lowerBound), MusicClip.fadeRange.upperBound) }
    }

    func setMusicFadeOut(_ id: UUID, _ seconds: TimeInterval) {
        updateMusic(id) { $0.fadeOut = min(max(seconds, MusicClip.fadeRange.lowerBound), MusicClip.fadeRange.upperBound) }
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
