//
//  AudioViewModel+Ducking.swift
//  Cue Studio
//

import Foundation

/// Music lowered under the voice (Volume › Lower under voice, on a picked music clip): how far it goes down, whether it stays low
/// in the pauses between sentences or comes back up, the same settings on every music clip at once, and ◐, which plays the music
/// without lowering so the difference is heard. Lowering follows the voice in the clips whose sound plays and the speech in each
/// voice-over (`SpokenSpans`). A clip saved before these settings keeps the first way until its lowering is touched; then it moves
/// to the current one (`MusicDuck.standard` with the change). Each change is an undo step; a drag of the slider is one.
extension AudioViewModel {
    /// The clip's lowering as the panel shows it: its own, or the current standard for a clip saved before.
    func duck(of music: MusicClip) -> MusicDuck {
        music.duck ?? .standard
    }

    func setMusicDucks(_ id: UUID, _ ducks: Bool) {
        endDuckingComparison()
        updateMusic(id) { music in
            music.ducksUnderVoice = ducks
            if ducks, music.duck == nil { music.duck = .standard }
        }
    }

    /// "Lower by": decibels under the voice.
    func setMusicDuckDepth(_ id: UUID, _ depth: Double) {
        endDuckingComparison()
        let depth = min(max(depth.rounded(), MusicDuck.depthRange.lowerBound), MusicDuck.depthRange.upperBound)
        updateMusic(id) { music in
            var duck = music.duck ?? .standard
            duck.depth = depth
            music.duck = duck
        }
    }

    /// "In pauses": stays low, or comes back up.
    func setMusicDuckPauses(_ id: UUID, _ pauses: MusicDuckPauses) {
        endDuckingComparison()
        updateMusic(id) { music in
            var duck = music.duck ?? .standard
            duck.pauses = pauses
            music.duck = duck
        }
    }

    // MARK: - Every music clip

    /// The music clips (not sound effects or sounds taken out of the video), in the order they play.
    private var musicClips: [MusicClip] {
        edit.music.filter(\.takesMusicRoom).sorted { $0.start < $1.start }
    }

    /// How many music clips "Use on all 3 music clips" changes.
    var musicClipCount: Int { musicClips.count }

    /// How many other music clips lower differently from `music`: "Use on all 3 music clips" shows when there's at least one.
    func musicLoweringDifferently(from music: MusicClip) -> Int {
        musicClips.filter { $0.id != music.id && !Self.lowersAlike($0, music) }.count
    }

    /// Every music clip lowers as `id` does (whether it does, how far, in pauses), in one undo step.
    func useLoweringOnAllMusic(from id: UUID) {
        guard let source = edit.music.first(where: { $0.id == id }) else { return }
        let count = musicClips.count
        let duck = source.ducksUnderVoice ? (source.duck ?? .standard) : source.duck
        change { snapshot in
            snapshot.music = snapshot.music?.map { clip in
                guard clip.takesMusicRoom else { return clip }
                var changed = clip
                changed.ducksUnderVoice = source.ducksUnderVoice
                changed.duck = duck
                return changed
            }
        }
        sayUndoable(String(localized: "Used on all \(count) music clips"))
    }

    private static func lowersAlike(_ one: MusicClip, _ other: MusicClip) -> Bool {
        guard one.ducksUnderVoice == other.ducksUnderVoice else { return false }
        return !one.ducksUnderVoice || (one.duck ?? .standard) == (other.duck ?? .standard)
    }

    // MARK: - Who it goes down under

    /// Where the music plays, in the Volume slider's own unit (owner, E4: "explicar o nível da música e quanto ela baixa sob a
    /// voz, numa linguagem só"): the percent of its file's level while someone talks and in the pauses ("While you talk: 10% ·
    /// in pauses: 40%"; 40% lowered by 12 dB is 10%). Nil when it doesn't go down.
    static func musicLevels(volume: Double, duck: MusicDuck?) -> String? {
        guard let duck else { return nil }
        let full = Int((volume * 100).rounded())
        let under = volume > 0 ? max(1, Int((volume * duck.level * 100).rounded())) : 0
        switch duck.pauses {
        case .staysLow: return String(localized: "While you talk and in pauses: \(under)%")
        case .comesBack: return String(localized: "While you talk: \(under)% · in pauses: \(full)%")
        }
    }

    /// "Under your voice and Voice-over 1": what speaks while the music plays (the clips whose sound is heard, the voice-overs
    /// over its span); "Nobody speaks while it plays" when nothing does.
    func loweringScope(of music: MusicClip) -> String {
        guard let span = music.span(inEditOf: edit.editedDuration) else { return String(localized: "Nobody speaks while it plays") }
        let voice = edit.timeline.segments.indices.contains { index in
            let segment = edit.timeline.segments[index]
            let start = edit.timeline.editedStart(ofSegmentAt: index)
            return !segment.isMuted && segment.volume > 0.001 && TimeSpan(start: start, end: start + segment.duration).overlaps(span)
        }
        let narrations = edit.voiceOvers.filter { clip in
            clip.volume > 0.001 && (clip.editedSpan(in: edit.timeline)?.overlaps(span) ?? false)
        }.count
        switch (voice, narrations) {
        case (true, 0): return String(localized: "Under your voice")
        case (true, _): return String(localized: "Under your voice and \(narrations) voice-overs")
        case (false, 0): return String(localized: "Nobody speaks while it plays")
        case (false, _): return String(localized: "Under \(narrations) voice-overs")
        }
    }

    // MARK: - ◐ Compare

    /// ◐ in Volume on a music clip that lowers: plays it without lowering, from a moment before the first voice under it.
    func duckingCompare(for music: MusicClip) -> PanelCompare {
        PanelCompare(
            isOn: comparedDuckingID == music.id, isEnabled: music.ducksUnderVoice && !music.isMuted,
            hint: String(localized: "Plays the music without lowering it"), identifier: "edit.compare.ducking"
        ) { [weak self] shows in
            guard let self else { return }
            if shows {
                startDuckingComparison(music)
            } else {
                endDuckingComparison()
                player.pause()
            }
        }
    }

    private func startDuckingComparison(_ music: MusicClip) {
        guard comparedDuckingID != music.id else { return }
        comparedDuckingID = music.id
        session.showPlayedEdit()
        if let span = music.span(inEditOf: edit.editedDuration), !span.contains(player.currentTime) {
            player.seek(to: comparisonStart(in: span))
        }
        player.play()
    }

    /// Where the difference is heard from, with the playhead outside the music: a second before the first voice-over under it
    /// when only narration speaks there, else the music's start.
    private func comparisonStart(in span: TimeSpan) -> TimeInterval {
        let voiceUnder = edit.timeline.segments.indices.contains { index in
            let segment = edit.timeline.segments[index]
            let start = edit.timeline.editedStart(ofSegmentAt: index)
            return !segment.isMuted && TimeSpan(start: start, end: start + segment.duration).overlaps(span)
        }
        guard !voiceUnder else { return span.start }
        let narration = edit.voiceOvers.compactMap { $0.editedSpan(in: edit.timeline)?.start }.filter { $0 >= span.start && $0 < span.end }.min()
        return narration.map { max(span.start, $0 - 1) } ?? span.start
    }

    /// Back to the music as it's lowered.
    func endDuckingComparison() {
        guard comparedDuckingID != nil else { return }
        comparedDuckingID = nil
        session.showPlayedEdit()
    }

    /// The edit as ◐ plays it: the compared music not lowered.
    func withoutComparedDucking(_ edit: TakeEdit) -> TakeEdit {
        guard let id = comparedDuckingID, let index = edit.music.firstIndex(where: { $0.id == id }) else { return edit }
        var played = edit
        played.music[index].ducksUnderVoice = false
        return played
    }
}
