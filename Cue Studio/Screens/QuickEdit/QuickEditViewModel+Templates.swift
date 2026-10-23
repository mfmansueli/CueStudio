//
//  QuickEditViewModel+Templates.swift
//  Cue Studio
//

import Foundation

/// ✦ Smart › Templates: a whole look for a kind of video (`VideoTemplate`) in one undo step. Captions get the template's look
/// and way of showing words (their lines stay), every text but graphics gets its type and motion (the words stay), new texts
/// start in it, and with no text yet a hook with the script's title opens the video.
extension QuickEditViewModel {
    /// The template the edit is in now: its captions look and show words the template's way and new texts start in its type.
    var appliedVideoTemplate: VideoTemplate? {
        VideoTemplate.allCases.first { template in
            edit.captionCollection?.theme == template.captionTheme && edit.captionAnimation == template.captionReveal
                && edit.textPreset == template.textPreset
        }
    }

    func applyVideoTemplate(_ template: VideoTemplate) {
        guard isReady else { return }
        let opening = coverSuggestions.first
        let look = template.textPreset.look(for: .title)
        let margins = captions.captionSafeMargins
        let hookSpan = edit.pin(placement(at: 0, length: template.openingRole.defaultDuration))
        var hook = edit.texts.contains(where: { $0.graphic == nil }) ? nil : opening.map { title in
            var text = TextOverlay(role: template.openingRole, look: look, preset: template.textPreset, span: hookSpan.span)
            text.text = title
            text.clipAnchor = hookSpan.anchor
            return text
        }
        hook?.animation = template.textMotion
        change { snapshot in
            var settings = template.captionSettings
            settings.center = snapshot.captionCollection?.center
            settings.safeMargins = snapshot.captionCollection?.safeMargins ?? margins
            snapshot.captionCollection = settings
            snapshot.captionAnimation = template.captionReveal
            for index in snapshot.texts.indices where snapshot.texts[index].graphic == nil {
                // Where the creator put each text stays: only its type and motion change.
                look.apply(to: &snapshot.texts[index], keeping: [.position, .alignment])
                snapshot.texts[index].preset = template.textPreset
                snapshot.texts[index].customized.formIntersection([.position, .alignment])
                snapshot.texts[index].animation = template.textMotion
            }
            if let hook { snapshot.texts.append(hook) }
            snapshot.textLook = look
            snapshot.textPreset = template.textPreset
        }
        player.pause()
        toast.show(
            String(localized: "\(template.label) on the whole video"),
            action: undoAction
        )
    }
}
