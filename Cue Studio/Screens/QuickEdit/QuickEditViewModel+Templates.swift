//
//  QuickEditViewModel+Templates.swift
//  Cue Studio
//

import Foundation

/// Templates: a whole look for a kind of video (`VideoTemplate`), tried on before it stays (`TemplateTrial`, owner 08/11/2026).
/// Captions get the template's look and way of showing words (their lines stay), every text but graphics gets its type and
/// motion (the words and the place stay), new texts start in it, and with no text yet a hook with the script's title opens the
/// video. What the creator styled by hand on a title or a caption line stays unless the sheet's switches say otherwise; on a
/// video that wears a kit, the kit's fonts and colors stay, and the sheet says so.
extension QuickEditViewModel {
    /// The template the edit is in now: its captions look and show words the template's way and new texts start in its type.
    var appliedVideoTemplate: VideoTemplate? {
        VideoTemplate.allCases.first { template in
            edit.captionCollection?.theme == template.captionTheme && edit.captionAnimation == template.captionReveal
                && edit.textPreset == template.textPreset
        }
    }

    /// A template card tapped: the template goes on the video (no undo step yet) and its sheet opens, saying what it changed.
    func tryVideoTemplate(_ template: VideoTemplate) {
        guard isReady else { return }
        if templateTrial != nil { document.cancelChanges() }
        player.pause()
        let before = EditSnapshot(edit)
        let manual = ManualStyleChanges(
            in: before, replacing: ManualStyleChanges.wholeLook.subtracting([.alignment]), touchesCaptions: !(before.captions ?? []).isEmpty
        )
        document.beginChange(by: .gesture)
        let hook = wear(template, replacing: ReplacedManualChanges())
        templateTrial = TemplateTrial(template: template, manual: manual, lines: lines(for: template, before: before, hook: hook))
    }

    /// A template put straight on, tried and kept in one go.
    func applyVideoTemplate(_ template: VideoTemplate) {
        tryVideoTemplate(template)
        keepVideoTemplate()
    }

    /// One of the sheet's switches: the template goes on again from how the video was, replacing those hand-made changes too.
    func setTemplateReplacing(_ replacing: ReplacedManualChanges) {
        guard var trial = templateTrial else { return }
        document.restartChange()
        wear(trial.template, replacing: replacing)
        trial.replacing = replacing
        templateTrial = trial
    }

    /// Apply: the template stays, one undo step, said with Undo.
    func keepVideoTemplate() {
        guard let trial = templateTrial else { return }
        templateTrial = nil
        document.endChange(by: .gesture)
        toast.show(String(localized: "\(trial.template.label) on the whole video"), action: undoAction)
    }

    /// Cancel (or the sheet swiped away): the video is as it was, with no undo step.
    func dropVideoTemplate() {
        guard templateTrial != nil else { return }
        templateTrial = nil
        document.cancelChanges()
    }

    /// Puts `template` on the edit; returns the opening text it added, if any.
    @discardableResult
    private func wear(_ template: VideoTemplate, replacing: ReplacedManualChanges) -> String? {
        let opening = cover.coverSuggestions.first
        let look = template.textPreset.look(for: .title)
        let margins = captions.captionSafeMargins
        let hookSpan = edit.pin(overlays.placement(at: 0, length: template.openingRole.defaultDuration))
        var hook = edit.texts.contains(where: { $0.graphic == nil }) ? nil : opening.map { title in
            var text = TextOverlay(role: template.openingRole, look: look, preset: template.textPreset, span: hookSpan.span)
            text.text = title
            text.clipAnchor = hookSpan.anchor
            return text
        }
        hook?.animation = template.textMotion
        change { snapshot in
            let wearsKit = snapshot.brandKit != nil
            let before = snapshot.captionCollection
            var settings = template.captionSettings
            settings.center = before?.center
            settings.safeMargins = before?.safeMargins ?? margins
            if wearsKit, let before { Self.keepKitLook(of: before, on: &settings) }
            snapshot.captionCollection = settings
            snapshot.captionAnimation = template.captionReveal
            if replacing.captionLines, let lines = snapshot.captions {
                snapshot.captions = lines.map { line in
                    var plain = line
                    plain.lineStyle = nil
                    return plain
                }
            }
            // A kit's fonts and colors stay on every text; where the creator put each text stays.
            let kitFields: Set<TextLookField> = wearsKit ? [.font, .weight, .color] : []
            for index in snapshot.texts.indices where snapshot.texts[index].graphic == nil {
                let mine = replacing.titles ? snapshot.texts[index].customized.intersection([.position, .alignment]) : snapshot.texts[index].customized
                look.apply(to: &snapshot.texts[index], keeping: mine.union([.position, .alignment]).union(kitFields))
                snapshot.texts[index].preset = template.textPreset
                snapshot.texts[index].customized = mine
                snapshot.texts[index].animation = template.textMotion
            }
            if var hook {
                if wearsKit, let kitLook = snapshot.textLook {
                    hook.font = kitLook.font
                    hook.weight = kitLook.weight
                    hook.color = kitLook.color
                }
                snapshot.texts.append(hook)
            }
            var newTexts = look
            if wearsKit, let kitLook = snapshot.textLook {
                newTexts.font = kitLook.font
                newTexts.weight = kitLook.weight
                newTexts.color = kitLook.color
            }
            snapshot.textLook = newTexts
            snapshot.textPreset = template.textPreset
        }
        return hook?.text
    }

    /// On a video that wears a kit, the captions keep the kit's type and colors under the template's shape and motion.
    private static func keepKitLook(of before: CaptionSettings, on settings: inout CaptionSettings) {
        if let face = before.face {
            settings.face = face
            if let weight = settings.adjustments?.weight, !settings.availableWeights.contains(weight) { settings.adjustments?.weight = nil }
        }
        if let accent = before.accent { settings.accent = accent }
        guard let kept = before.adjustments else { return }
        var adjustments = settings.adjustments ?? CaptionAdjustments()
        if let color = kept.textColor { adjustments.textColor = color }
        if let color = kept.backgroundColor { adjustments.backgroundColor = color }
        if let color = kept.outlineColor { adjustments.outlineColor = color }
        if let color = kept.emphasisColor { adjustments.emphasisColor = color }
        settings.adjustments = adjustments.isEmpty ? nil : adjustments
    }

    /// What the sheet says `template` changes on a video that was `before`.
    private func lines(for template: VideoTemplate, before: EditSnapshot, hook: String?) -> [TemplateTrial.Line] {
        let kit = before.brandKit?.name
        let keepsKit = kit.map { String(localized: "keeps \($0)'s fonts and colors", comment: "Template sheet: a kit's look that stays") }
        var lines: [TemplateTrial.Line] = []
        let ownCustom = kit == nil && !(before.captionCollection?.adjustments?.isEmpty ?? true)
        let captionsDetail = (before.captions ?? []).isEmpty
            ? String(localized: "For the captions you make")
            : String(localized: "Lines, timing and place stay")
        lines.append(TemplateTrial.Line(
            id: "captions", systemImage: "captions.bubble", title: String(localized: "Caption style · \(template.label)"),
            detail: [captionsDetail, keepsKit, ownCustom ? String(localized: "your Custom colors change too") : nil].compactMap { $0 }.joined(separator: " · ")
        ))
        let texts = before.texts.filter { $0.graphic == nil }.count
        let textsDetail = switch texts {
        case 0: String(localized: "New texts start in it")
        case 1: String(localized: "Type and motion on the text · words and place stay")
        default: String(localized: "Type and motion on \(texts) texts · words and place stay")
        }
        lines.append(TemplateTrial.Line(
            id: "texts", systemImage: "textformat", title: String(localized: "Text style"),
            detail: [textsDetail, keepsKit].compactMap { $0 }.joined(separator: " · ")
        ))
        if let hook {
            lines.append(TemplateTrial.Line(
                id: "hook", systemImage: "text.badge.plus", title: String(localized: "Opening text"),
                detail: String(localized: "“\(hook)” at the start")
            ))
        }
        return lines
    }
}
