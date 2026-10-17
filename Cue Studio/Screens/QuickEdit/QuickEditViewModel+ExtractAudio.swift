//
//  QuickEditViewModel+ExtractAudio.swift
//  Cue Studio
//

import Foundation

/// Extract audio (CapCut's way): the sound of the picked clip (the take or another recording, as Studio Voice treats it and at
/// the clip's speed or along its curve) or of a video over the take goes to a track of its own on the music track, where it plays right where
/// it did and can be moved, trimmed, faded and turned up or down; the clip or the video is muted, so nothing plays twice. Like
/// a sound effect, it follows its moment when something before it is cut. One undo step brings both back; the recording is
/// never touched.
extension QuickEditViewModel {
    /// Whether the picked item has a sound to extract: a clip, or a video over the take with a sound of its own.
    var canExtractAudio: Bool {
        if selection?.clipID != nil { return true }
        guard let media = selectedMedia else { return false }
        return media.kind == .video && media.hasSound == true
    }

    /// Clip › Extract audio, or Media › Extract audio.
    func extractAudio() async {
        guard isReady, !isImportingMedia else { return }
        if let id = selection?.clipID {
            await extractAudio(ofClip: id)
        } else if let id = selection?.mediaID {
            await extractAudio(ofMedia: id)
        }
    }

    // MARK: - A clip

    private func extractAudio(ofClip id: UUID) async {
        let timeline = edit.timeline
        guard let index = timeline.index(ofSegment: id) else { return }
        let segment = timeline.segments[index]
        // A muted clip (its sound already taken out, or turned off) has nothing to extract: its sound would play again.
        guard !segment.isMuted, segment.volume > 0 else {
            toast.show(String(localized: "This clip is muted · Turn its sound on to extract it"))
            return
        }
        let request = SoundExtraction(
            videoURL: segment.sourceID.flatMap { clipSourceURLs[$0] } ?? videoURL, span: segment.span, speed: segment.speed,
            keepsPitch: segment.keepsPitch, curve: segment.speedCurve,
            treatment: .init(edit: edit, takeURL: videoURL, recording: segment.sourceID)
        )
        guard let sound = await extract(request) else { return }
        // The sound took a moment: if the cuts changed meanwhile, the place it was for may be gone.
        guard edit.timeline == timeline else { return discardExtracted(sound) }
        var clip = extractedClip(sound, title: String(localized: "Sound · Clip \(index + 1)"), start: timeline.editedStart(ofSegmentAt: index))
        clip.extractedFrom = .clip
        clip.volume = min(max(segment.volume, MusicClip.volumeRange.lowerBound), MusicClip.volumeRange.upperBound)
        var muted = segment
        muted.isMuted = true
        change { snapshot in
            snapshot.timeline.replaceSegment(muted)
            snapshot.music = (snapshot.music ?? []) + [clip]
        }
        finishExtracting(clip, message: String(localized: "Sound on its own track · the clip is muted"))
    }

    // MARK: - A video over the take

    private func extractAudio(ofMedia id: UUID) async {
        let timeline = edit.timeline
        guard let placed = edit.editedMedia(in: timeline).first(where: { $0.media.id == id }) else { return }
        let media = placed.media
        guard media.kind == .video, media.hasSound == true else {
            toast.show(String(localized: "This video has no sound"))
            return
        }
        guard let volume = media.audioVolume, volume > 0 else {
            toast.show(String(localized: "This video is muted · Turn its sound on to extract it"))
            return
        }
        let start = media.startInFile
        let request = SoundExtraction(
            videoURL: EditMediaFiles.url(for: media.fileName), span: TimeSpan(start: start, end: start + placed.span.duration)
        )
        guard let sound = await extract(request) else { return }
        guard edit.timeline == timeline, edit.media.contains(where: { $0.id == id }) else { return discardExtracted(sound) }
        var clip = extractedClip(sound, title: String(localized: "Sound · Video"), start: placed.span.start)
        clip.extractedFrom = .media
        clip.volume = volume
        change { snapshot in
            guard let index = snapshot.media.firstIndex(where: { $0.id == id }) else { return }
            snapshot.media[index].audioVolume = nil
            snapshot.music = (snapshot.music ?? []) + [clip]
        }
        finishExtracting(clip, message: String(localized: "Sound on its own track · the video is muted"))
    }

    // MARK: - Private

    private func extract(_ request: SoundExtraction) async -> ExtractedSound? {
        isImportingMedia = true
        defer { isImportingMedia = false }
        player.pause()
        toast.show(String(localized: "Extracting the sound…"))
        do {
            let sound = try await editing.extractSound(request)
            guard !isClosed else {
                EditMediaFiles.remove([sound.fileName])
                return nil
            }
            importedFiles.insert(sound.fileName)
            return sound
        } catch AudioTrackExtractor.ExtractError.noAudio {
            toast.show(String(localized: "This clip has no sound"))
        } catch {
            toast.show(String(localized: "Can't extract this sound"))
        }
        return nil
    }

    private func discardExtracted(_ sound: ExtractedSound) {
        EditMediaFiles.remove([sound.fileName])
        importedFiles.remove(sound.fileName)
        toast.show(String(localized: "The video changed meanwhile · Extract the sound again"))
    }

    /// The new clip on the music track: where the sound played, at its own level, with no fades and never ducking (it's the
    /// voice itself, often).
    private func extractedClip(_ sound: ExtractedSound, title: String, start: TimeInterval) -> MusicClip {
        var clip = MusicClip(
            fileName: sound.fileName, title: title, fileDuration: sound.duration, start: start,
            length: min(sound.duration, max(0, edit.editedDuration - start))
        )
        clip.fadeIn = 0
        clip.fadeOut = 0
        clip.ducksUnderVoice = false
        return clip
    }

    /// The new track is picked, so its tools (Volume, Delete) are at hand, with the playhead where it starts.
    private func finishExtracting(_ clip: MusicClip, message: String) {
        selection = .music(clip.id)
        player.seek(to: clip.start)
        toast.show(message, action: ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() })
    }
}
