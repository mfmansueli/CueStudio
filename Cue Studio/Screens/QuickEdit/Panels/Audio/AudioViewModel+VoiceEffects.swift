//
//  AudioViewModel+VoiceEffects.swift
//  Cue Studio
//

import Foundation

/// Voice effects (on a clip's or a voice-over's bar): a creative effect on that one voice, None to hear it as it was, "Amount"
/// for how much, and ◐ to hear it without the effect. Apart from Studio Voice, which only makes the voice clearer. Picking an
/// effect plays the voice from its start when the playhead isn't on it, so it's heard at once. Each change is an undo step; a
/// drag of "Amount" is one.
extension AudioViewModel {
    /// The picked voice-over, else the picked clip (or the clip under the playhead, as the panel pins it).
    var voiceEffectTarget: VoiceEffectTarget? {
        if let id = selection?.voiceOverID, edit.voiceOvers.contains(where: { $0.id == id }) { return .voiceOver(id) }
        return targetClip.map { .clip($0.id) }
    }

    func voiceEffect(of target: VoiceEffectTarget) -> VoiceEffectSetting? {
        switch target {
        case .clip(let id): edit.timeline.segment(id: id)?.voiceEffect
        case .voiceOver(let id): edit.voiceOvers.first { $0.id == id }?.voiceEffect
        }
    }

    /// The panel's subtitle: where the effect lands, and what the picked one is for ("Voice-over 1 · A machine talking").
    var voiceEffectsSubtitle: String {
        let use = voiceEffectTarget.flatMap(voiceEffect(of:))?.effect.use ?? String(localized: "a creative effect on the voice")
        return "\(voiceEffectScope) · \(use)"
    }

    /// Where the effect lands: "Clip 2 of 3", or the voice-over's name.
    var voiceEffectScope: String {
        guard case .voiceOver(let id)? = voiceEffectTarget, let index = edit.voiceOvers.firstIndex(where: { $0.id == id }) else {
            return clipScope
        }
        return edit.voiceOvers[index].spoken == nil
            ? String(localized: "Voice-over \(index + 1)")
            : String(localized: "Read-aloud voice-over \(index + 1)")
    }

    /// A clip that plays no sound has no voice to change.
    var voiceEffectIsHeard: Bool {
        switch voiceEffectTarget {
        case .clip(let id)?: edit.timeline.segment(id: id).map { !$0.isMuted && $0.volume > 0.001 } ?? false
        case .voiceOver?: true
        case nil: false
        }
    }

    /// None (nil) or an effect, keeping the amount the voice had.
    func setVoiceEffect(_ effect: VoiceEffect?) {
        guard let target = voiceEffectTarget else { return }
        endVoiceEffectComparison()
        let amount = voiceEffect(of: target)?.amount ?? VoiceEffectSetting.defaultAmount
        update(target) { $0 = effect.map { VoiceEffectSetting(effect: $0, amount: amount) } }
        if effect != nil { play(target) }
    }

    /// "Amount", 10 to 100%.
    func setVoiceEffectAmount(_ amount: Double) {
        guard let target = voiceEffectTarget, var setting = voiceEffect(of: target) else { return }
        endVoiceEffectComparison()
        setting.amount = amount
        update(target) { $0 = setting }
    }

    private func update(_ target: VoiceEffectTarget, _ apply: (inout VoiceEffectSetting?) -> Void) {
        switch target {
        case .clip:
            updateClip { apply(&$0.voiceEffect) }
        case .voiceOver(let id):
            change { snapshot in
                guard let index = snapshot.voiceOvers.firstIndex(where: { $0.id == id }) else { return }
                apply(&snapshot.voiceOvers[index].voiceEffect)
            }
        }
    }

    /// Plays the voice from its start, unless the playhead is already on it.
    private func play(_ target: VoiceEffectTarget) {
        guard let span = editedSpan(of: target) else { return }
        if !span.contains(player.currentTime) { player.seek(to: span.start) }
        if !player.isPlaying { player.play() }
    }

    private func editedSpan(of target: VoiceEffectTarget) -> TimeSpan? {
        switch target {
        case .clip(let id):
            guard let index = edit.timeline.index(ofSegment: id) else { return nil }
            let start = edit.timeline.editedStart(ofSegmentAt: index)
            return TimeSpan(start: start, end: start + edit.timeline.segments[index].duration)
        case .voiceOver(let id):
            return edit.voiceOvers.first { $0.id == id }?.editedSpan(in: edit.timeline)
        }
    }

    // MARK: - ◐ Compare

    /// ◐ in Voice effects: plays the voice without its effect, until tapped again.
    var voiceEffectCompare: PanelCompare {
        let target = voiceEffectTarget
        return PanelCompare(
            isOn: target != nil && comparedVoiceEffect == target, isEnabled: target.flatMap(voiceEffect(of:)) != nil,
            hint: String(localized: "Plays the voice without the effect"), identifier: "edit.compare.voiceEffect"
        ) { [weak self] shows in
            guard let self else { return }
            if shows, let target {
                comparedVoiceEffect = target
                session.showPlayedEdit()
                play(target)
            } else {
                endVoiceEffectComparison()
                player.pause()
            }
        }
    }

    /// Back to the voice with its effect.
    func endVoiceEffectComparison() {
        guard comparedVoiceEffect != nil else { return }
        comparedVoiceEffect = nil
        session.showPlayedEdit()
    }

    /// The edit as ◐ plays it: the compared voice without its effect.
    func withoutComparedVoiceEffect(_ edit: TakeEdit) -> TakeEdit {
        guard let target = comparedVoiceEffect else { return edit }
        var played = edit
        switch target {
        case .clip(let id):
            guard var segment = played.timeline.segment(id: id) else { return edit }
            segment.voiceEffect = nil
            _ = played.timeline.replaceSegment(segment)
        case .voiceOver(let id):
            guard let index = played.voiceOvers.firstIndex(where: { $0.id == id }) else { return edit }
            played.voiceOvers[index].voiceEffect = nil
        }
        return played
    }
}
