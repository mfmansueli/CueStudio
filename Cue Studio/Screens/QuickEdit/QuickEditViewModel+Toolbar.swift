//
//  QuickEditViewModel+Toolbar.swift
//  Cue Studio
//

import Foundation

/// The toolbar by context: the main tools with nothing picked; the picked item's own tools (Clip,
/// Text, Caption, Music, Voice-over, Media) with a yellow "‹" back to the main ones; and the Text,
/// Captions and Audio menus, which a tap on their track opens too. Speed and Zoom stay two
/// separate tools. Delete is always the last tool and stays put (see `EditorToolbarItem.isPinned`).
extension QuickEditViewModel {
    /// The name next to the back button; nil on the main toolbar.
    var toolbarContextLabel: String? {
        selection?.contextLabel ?? toolMenu?.contextLabel
    }

    var toolbarItems: [EditorToolbarItem] {
        if let selection { return items(for: selection) }
        switch toolMenu {
        case .text: return textMenuItems
        case .captions: return captionsMenuItems
        case .audio: return audioMenuItems
        case nil: return mainItems
        }
    }

    /// Back to the main toolbar.
    func leaveToolbarContext() {
        selection = nil
        toolMenu = nil
    }

    // MARK: - Contexts

    /// The main tools, in the order a talking-head video is made (owner's decision, 2026-10-16, after comparing with CapCut and
    /// Edits; the v29 board had CapCut's older order): cut, captions, the hook's text, ✦ Smart (pauses, Studio Voice, Edit by
    /// text), B-roll — the five on screen on an iPhone — then sound, the format of the whole video, its look (Adjust, Filters)
    /// and the cover.
    private var mainItems: [EditorToolbarItem] {
        [
            EditorToolbarItem(id: "edit", label: String(localized: "Edit"), systemImage: "scissors", action: .selectClipAtPlayhead),
            EditorToolbarItem(id: "captions", label: String(localized: "Captions"), systemImage: "captions.bubble", action: .openCaptions),
            EditorToolbarItem(id: "text", label: String(localized: "Text"), systemImage: "textformat", action: .openMenu(.text)),
            EditorToolbarItem(id: "smart", label: String(localized: "✦ Smart"), systemImage: "sparkles", style: .smart, action: .open(.smart)),
            EditorToolbarItem(id: "addMedia", label: String(localized: "Media"), systemImage: "photo.badge.plus", action: .addMediaChoice),
            EditorToolbarItem(id: "audio", label: String(localized: "Audio"), systemImage: "music.note", action: .openMenu(.audio)),
            EditorToolbarItem(id: "format", label: String(localized: "Format"), systemImage: "aspectratio", action: .open(.crop)),
            // The whole video's look, side by side: Adjust (light and color) and Filters.
            EditorToolbarItem(id: "adjustVideo", label: String(localized: "Adjust"), systemImage: "slider.horizontal.3", action: .open(.adjust)),
            EditorToolbarItem(id: "filters", label: String(localized: "Filters"), systemImage: "camera.filters", action: .open(.filters)),
            EditorToolbarItem(id: "cover", label: String(localized: "Cover"), systemImage: "photo.artframe", action: .openCoverStudio),
        ]
    }

    private var textMenuItems: [EditorToolbarItem] {
        var items = [
            EditorToolbarItem(id: "title", label: String(localized: "Title"), systemImage: "textformat.size.larger", action: .addText(.title)),
            EditorToolbarItem(
                id: "subtitle", label: String(localized: "Subtitle"), systemImage: TextOverlayRole.subtitle.systemImage, action: .addText(.subtitle)
            ),
            EditorToolbarItem(id: "hook", label: String(localized: "Hook"), systemImage: TextOverlayRole.hook.systemImage, action: .addText(.hook)),
            EditorToolbarItem(id: "callout", label: String(localized: "Callout"), systemImage: "text.bubble", action: .addText(.callout)),
        ]
        items += [CoverItemKind.arrow, .circle, .tag].map { kind in
            EditorToolbarItem(
                id: "graphic.\(kind.rawValue)", label: kind.label, systemImage: kind.systemImage, action: .addGraphic(kind),
                startsGroup: kind == .arrow
            )
        }
        if overlays.commentForCard != nil {
            items.append(EditorToolbarItem(id: "comment", label: String(localized: "Comment"), systemImage: "text.bubble.fill", action: .addCommentCard))
        }
        if !edit.texts.isEmpty {
            items.append(EditorToolbarItem(id: "styleAll", label: String(localized: "Style all"), systemImage: "square.grid.2x2", action: .styleAllTexts))
        }
        return items
    }

    /// With lines: add one, the list, the style. Without: make them, or write them.
    private var captionsMenuItems: [EditorToolbarItem] {
        if edit.captions.isEmpty {
            return [
                EditorToolbarItem(id: "autoCaptions", label: String(localized: "Auto captions"), systemImage: "captions.bubble", action: .openCaptions),
                EditorToolbarItem(id: "writeCaptions", label: String(localized: "Write them"), systemImage: "pencil", action: .writeCaptionsByHand),
                EditorToolbarItem(id: "editByText", label: String(localized: "Edit by text"), systemImage: "text.badge.minus", action: .editByText),
            ]
        }
        return [
            EditorToolbarItem(id: "addLine", label: String(localized: "Add line"), systemImage: "plus.bubble", action: .addCaptionLine),
            EditorToolbarItem(id: "allLines", label: String(localized: "All lines"), systemImage: "list.bullet", action: .openCaptions),
            EditorToolbarItem(id: "style", label: String(localized: "Style"), systemImage: "textformat.alt", action: .open(.captionStyle)),
            EditorToolbarItem(
                id: "findReplace", label: String(localized: "Find and replace"), systemImage: "text.magnifyingglass", action: .findInCaptions
            ),
            EditorToolbarItem(id: "editByText", label: String(localized: "Edit by text"), systemImage: "text.badge.minus", action: .editByText),
            EditorToolbarItem(
                id: "deleteAll", label: String(localized: "Delete all"), systemImage: "trash", style: .destructive, action: .deleteAllCaptions
            ),
        ]
    }

    private var audioMenuItems: [EditorToolbarItem] {
        [
            EditorToolbarItem(id: "voice", label: String(localized: "Studio Voice"), systemImage: "waveform.and.mic", action: .open(.voice)),
            EditorToolbarItem(id: "music", label: String(localized: "Music"), systemImage: "music.note", action: .openMusic),
            EditorToolbarItem(id: "voiceOver", label: String(localized: "Voice-over"), systemImage: "mic", action: .open(.voiceOver)),
        ]
    }

    /// Lock or Unlock for the picked layer.
    private var lockItem: EditorToolbarItem {
        selectionIsLocked
            ? EditorToolbarItem(id: "unlock", label: String(localized: "Unlock"), systemImage: "lock.open", action: .toggleLock)
            : EditorToolbarItem(id: "lock", label: String(localized: "Lock"), systemImage: "lock", action: .toggleLock)
    }

    private func items(for selection: EditorSelection) -> [EditorToolbarItem] {
        let delete = String(localized: "Delete")
        switch selection {
        case .clip:
            // The clip's own tools, most used first (Split, Speed, the punch-in Zoom, Volume) so they're the ones on screen;
            // what changes the whole video lives on the main bar (Format, Audio › Studio Voice, Media).
            return [
                EditorToolbarItem(
                    id: "split", label: String(localized: "Split"), systemImage: "arrow.left.and.line.vertical.and.arrow.right",
                    style: canSplitSelectedClip ? .normal : .dimmed, action: .splitClip
                ),
                EditorToolbarItem(id: "speed", label: String(localized: "Speed"), systemImage: "gauge.with.dots.needle.67percent", action: .open(.speed)),
                EditorToolbarItem(id: "zoom", label: String(localized: "Zoom"), systemImage: "arrow.up.left.and.arrow.down.right", action: .open(.zoom)),
                EditorToolbarItem(id: "volume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", action: .open(.volume)),
                EditorToolbarItem(
                    id: "stabilize", label: String(localized: "Stabilize"), systemImage: "camera.metering.center.weighted", action: .open(.stabilize)
                ),
                EditorToolbarItem(id: "duplicate", label: String(localized: "Duplicate"), systemImage: "plus.square.on.square", action: .duplicateClip),
                EditorToolbarItem(id: "freeze", label: String(localized: "Freeze frame"), systemImage: "pause.rectangle", action: .freezeFrame),
                EditorToolbarItem(id: "reverse", label: String(localized: "Reverse"), systemImage: "backward.end.alt", action: .reverseClip),
                EditorToolbarItem(id: "replace", label: String(localized: "Replace"), systemImage: "arrow.left.arrow.right", action: .replaceClip),
                EditorToolbarItem(
                    id: "extractAudio", label: String(localized: "Extract audio"), systemImage: "waveform.badge.plus", action: .extractAudio
                ),
                EditorToolbarItem(
                    id: "reorder", label: String(localized: "Reorder"), systemImage: "arrow.up.arrow.down",
                    style: edit.timeline.segments.count > 1 ? .normal : .dimmed, action: .reorderClips
                ),
                EditorToolbarItem(id: "adjust", label: String(localized: "Adjust"), systemImage: "slider.horizontal.3", action: .open(.adjust)),
                EditorToolbarItem(id: "filters", label: String(localized: "Filters"), systemImage: "camera.filters", action: .open(.filters)),
                EditorToolbarItem(
                    id: "background", label: String(localized: "Background"), systemImage: "person.and.background.dotted", action: .open(.background)
                ),
                EditorToolbarItem(id: "copyLook", label: String(localized: "Copy look"), systemImage: "doc.on.doc", action: .copyLook),
                EditorToolbarItem(
                    id: "pasteLook", label: String(localized: "Paste look"), systemImage: "doc.on.clipboard",
                    style: look.canPasteLook ? .normal : .dimmed, action: .pasteLook
                ),
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteClip),
            ]
        case .text:
            return [
                EditorToolbarItem(id: "editText", label: String(localized: "Edit"), systemImage: "pencil", action: .editText),
                EditorToolbarItem(id: "style", label: String(localized: "Style"), systemImage: "textformat.alt", action: .open(.textStyle)),
                EditorToolbarItem(id: "animation", label: String(localized: "Motion"), systemImage: "wind", action: .openTextAnimation),
                EditorToolbarItem(id: "keyframe", label: String(localized: "Keyframe"), systemImage: "diamond", action: .toggleKeyframe),
                EditorToolbarItem(id: "track", label: String(localized: "Track"), systemImage: "scope", action: .trackItem),
                EditorToolbarItem(id: "duplicate", label: String(localized: "Duplicate"), systemImage: "plus.square.on.square", action: .duplicateText),
                lockItem,
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteText),
            ]
        case .caption:
            return [
                EditorToolbarItem(id: "editCaption", label: String(localized: "Edit"), systemImage: "pencil", action: .editCaption),
                EditorToolbarItem(
                    id: "split", label: String(localized: "Split"), systemImage: "arrow.left.and.line.vertical.and.arrow.right", action: .splitCaption
                ),
                EditorToolbarItem(
                    id: "join", label: String(localized: "Join next"), systemImage: "arrow.right.and.line.vertical.and.arrow.left", action: .joinCaption
                ),
                EditorToolbarItem(id: "style", label: String(localized: "Style"), systemImage: "textformat.alt", action: .open(.captionStyle)),
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteCaption),
            ]
        case .music(let id):
            // Beats for the creator's music from Files, not for a sound effect or a sound taken out of the video.
            let isMusic = edit.music.first { $0.id == id }.map { !$0.followsTheVideo } ?? false
            return [
                EditorToolbarItem(id: "volume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", action: .open(.volume)),
            ] + (isMusic ? [EditorToolbarItem(id: "beats", label: String(localized: "Beats"), systemImage: "metronome", action: .open(.beats))] : []) + [
                EditorToolbarItem(id: "replace", label: String(localized: "Replace"), systemImage: "arrow.left.arrow.right", action: .replaceMusic),
                lockItem,
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteMusic),
            ]
        case .voiceOver:
            return [
                EditorToolbarItem(id: "volume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", action: .open(.volume)),
                EditorToolbarItem(id: "reRecord", label: String(localized: "Re-record"), systemImage: "mic.badge.plus", action: .reRecordVoiceOver),
                lockItem,
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteVoiceOver),
            ]
        case .media:
            var items = [
                EditorToolbarItem(id: "editMedia", label: String(localized: "Edit"), systemImage: "pencil", action: .open(.media)),
                EditorToolbarItem(id: "track", label: String(localized: "Track"), systemImage: "scope", action: .trackItem),
                EditorToolbarItem(id: "duplicate", label: String(localized: "Duplicate"), systemImage: "plus.square.on.square", action: .duplicateMedia),
                EditorToolbarItem(id: "replaceMedia", label: String(localized: "Replace"), systemImage: "arrow.left.arrow.right", action: .replaceMedia),
            ]
            // Only a video with a sound of its own has one to take out.
            if audio.canExtractAudio {
                items.append(EditorToolbarItem(
                    id: "extractAudio", label: String(localized: "Extract audio"), systemImage: "waveform.badge.plus", action: .extractAudio
                ))
            }
            items.append(lockItem)
            items.append(EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteMedia))
            return items
        case .join:
            // A cut is picked only with its Transition panel open, which takes the toolbar's place.
            return []
        }
    }

    // MARK: - Performing

    func perform(_ action: EditorAction) {
        guard isReady else { return }
        if performOnSelection(action) { return }
        switch action {
        case .selectClipAtPlayhead: selectClipAtPlayhead()
        case .openMenu(let menu):
            selection = nil
            toolMenu = menu
        case .openCaptions: openCaptions()
        case .addCaptionLine:
            openCaptions()
            captions.addCaptionAtPlayhead()
        case .open(let panel):
            // From a picked clip, Adjust, Filters and Background change that clip only.
            look.lookScopeIsClip = panel.hasClipScope && selection?.clipID != nil
            self.panel = panel
        case .addMedia, .addMediaChoice:
            overlays.mediaInsertMode = .overlay
            sheet = .media
        case .addText, .addGraphic, .addCommentCard, .styleAllTexts, .editText: performTextAction(action)
        case .deleteAllCaptions: captions.deleteAllCaptions()
        case .findInCaptions: captions.openCaptionFind()
        case .editByText:
            toolMenu = nil
            panel = nil
            transcriptSelection = nil
            sheet = .transcript
        case .writeCaptionsByHand:
            toolMenu = nil
            captions.writeCaptionsByHand()
        case .openMusic, .replaceMusic: openMusicSheet(replacing: action == .replaceMusic)
        case .openCoverStudio: cover.openCoverStudio()
        default: break
        }
    }

    /// The Text menu's actions and Edit on a picked text.
    private func performTextAction(_ action: EditorAction) {
        switch action {
        case .addText(let role): overlays.addStyledText(role)
        case .addGraphic(let kind): overlays.addGraphic(kind)
        case .addCommentCard: overlays.addCommentCard()
        case .styleAllTexts: styleAllTexts()
        case .editText:
            panel = .textStyle
            overlays.focusesTextField = true
        default: break
        }
    }

    /// Always adds: a clip already there is picked on its track, and "Replace" swaps it.
    private func openMusicSheet(replacing: Bool) {
        guard !replacing || selection?.musicID != nil else { return }
        audio.musicReplacementID = replacing ? selection?.musicID : nil
        sheet = .music
    }

    /// The actions on the picked item. False when `action` isn't one of them.
    private func performOnSelection(_ action: EditorAction) -> Bool {
        if performOnClip(action) || performOnMotion(action) { return true }
        switch action {
        case .duplicateText: selection?.textID.map(overlays.duplicateText)
        case .toggleLock: toggleLockOfSelection()
        case .duplicateMedia: selection?.mediaID.map(overlays.duplicateMedia)
        case .deleteText: selection?.textID.map(overlays.deleteText)
        case .editCaption:
            panel = .captions
            captions.focusesCaptionField = true
        case .splitCaption: selection?.captionID.map(captions.splitCaptionAtPlayhead)
        case .joinCaption: selection?.captionID.map(captions.joinCaption)
        case .deleteCaption: selection?.captionID.map(captions.deleteCaptionLine)
        case .deleteMusic: selection?.musicID.map(audio.deleteMusic)
        case .reRecordVoiceOver: selection?.voiceOverID.map(audio.reRecordVoiceOver)
        case .deleteVoiceOver: selection?.voiceOverID.map(audio.deleteVoiceOver)
        case .replaceMedia: replaceSelectedMedia()
        case .deleteMedia: selection?.mediaID.map(overlays.deleteMedia)
        default: return false
        }
        return true
    }

    /// How the picked text or photo moves: keyframes, Track, ready animations. False when `action` isn't one of them.
    private func performOnMotion(_ action: EditorAction) -> Bool {
        switch action {
        case .toggleKeyframe: overlays.toggleKeyframe()
        case .trackItem: overlays.trackSelectedItem()
        case .openTextAnimation:
            overlays.textStyleScope = .selected
            panel = .textStyle
            panelTab = .motion
        default: return false
        }
        return true
    }

    /// The actions on a picked clip. False when `action` isn't one of them.
    private func performOnClip(_ action: EditorAction) -> Bool {
        switch action {
        case .splitClip: splitClip()
        case .duplicateClip: selection?.clipID.map(duplicateClip)
        case .reorderClips: openClipOrder()
        case .freezeFrame: startJob { await self.freezeFrame() }
        case .reverseClip:
            // One at a time: a second tap never stops the first.
            if !jobs.isRunning(.reverse) { jobs.start(.reverse) { [weak self] _ in await self?.reverseClip() } }
        case .replaceClip: askToReplaceClip()
        case .extractAudio: startJob { await self.audio.extractAudio() }
        case .copyLook: look.copyClipLook()
        case .pasteLook: look.askToPasteLook()
        case .deleteClip: selection?.clipID.map(deleteClip)
        default: return false
        }
        return true
    }

    private func replaceSelectedMedia() {
        guard let media = selectedMedia else { return }
        requestPhoto(.replaceMedia(media.id, kind: media.kind))
    }

    /// Captions: the list when the take has lines, else Auto captions to make them.
    func openCaptions() {
        selection = nil
        toolMenu = nil
        panel = edit.captions.isEmpty ? .autoCaptions : .captions
    }

    /// "Style all": the Text style panel for every text at once.
    func styleAllTexts() {
        guard let first = edit.texts.first else { return }
        selection = .text(first.id)
        overlays.textStyleScope = .allTexts
        panel = .textStyle
    }
}
