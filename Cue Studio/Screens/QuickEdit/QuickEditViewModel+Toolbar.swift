//
//  QuickEditViewModel+Toolbar.swift
//  Cue Studio
//

import Foundation

/// The toolbar by context: the main tools with nothing picked (`+MainToolbar`); the picked item's own tools and then the others
/// (`+ItemToolbar`), with a yellow "‹" back to the main ones; and the Text, Captions and Audio menus, which a tap on their track
/// opens too. Every button goes through `perform(_:)`, which checks at the tap that the action can work and says why when it
/// can't. Delete is always the last tool and stays put (see `EditorToolbarItem.isPinned`).
extension QuickEditViewModel {
    /// Which tools show (the picked item's kind or the open menu), in code: picking another item of the same kind keeps the
    /// tools where they were scrolled.
    var toolbarContext: EditorToolbarContext {
        guard let selection else { return toolMenu.map(EditorToolbarContext.menu) ?? .main }
        switch selection {
        case .clip: return .clip
        case .text: return .text
        case .caption: return .caption
        case .music: return .music
        case .voiceOver: return .voiceOver
        case .media: return isSplitMainAreaPicked ? .mainArea : .media
        case .blur: return .blur
        case .join: return .transition
        }
    }

    /// The main video's area of a split screen is picked (its own tools, never the support's).
    var isSplitMainAreaPicked: Bool {
        selectedMedia?.layout == .split && overlays.selectedArea == .main
    }

    /// The name next to the back button: which item the tools change ("Clip 2" in a montage, "Photo", "Hook", "Arrow"), or
    /// the open menu.
    var toolbarContextName: String? {
        guard let selection else { return toolMenu?.contextLabel }
        switch selection {
        case .clip(let id):
            guard edit.timeline.segments.count > 1, let index = edit.timeline.index(ofSegment: id) else { return selection.contextLabel }
            return String(localized: "Clip \(index + 1)")
        case .text:
            guard let text = selectedText else { return selection.contextLabel }
            return text.graphic?.kind.label ?? text.role.label
        case .media:
            guard let media = selectedMedia else { return selection.contextLabel }
            if isSplitMainAreaPicked { return String(localized: "Main video") }
            return media.kind == .photo ? String(localized: "Photo") : String(localized: "Video")
        case .blur:
            guard let region = selectedBlur else { return selection.contextLabel }
            return region.subject.label
        case .caption, .music, .voiceOver, .join:
            return selection.contextLabel
        }
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

    // MARK: - Tapping

    /// A toolbar button. A tool with the whole video's badge tapped on an item's bar first says once (per tool and kind of item,
    /// while the editor is open) that it changes the whole video, not only that item; then it does what it always does.
    func tap(_ item: EditorToolbarItem) {
        guard isReady else { return }
        let context = toolbarContext
        if item.scopeBadge == .wholeVideo, context.isItem, let name = toolbarContextName,
           scopeNoticesSaid[context, default: []].insert(item.id).inserted {
            toast.show(String(localized: "Applies to the whole video, not only to \(name)."), kind: .cue)
        }
        perform(item.action)
    }

    // MARK: - Performing

    func perform(_ action: EditorAction) {
        // While a narration records the bar is off; nothing reaches the edit another way (VoiceOver, a keyboard) either.
        guard isReady, !audio.isRecordingVoiceOver else { return }
        if performOnSelection(action) || performOpening(action) { return }
        switch action {
        case .selectClipAtPlayhead: clips.selectClipAtPlayhead()
        case .addCaptionLine:
            openCaptions()
            captions.addCaptionAtPlayhead()
        case .addMedia, .addMediaChoice:
            overlays.mediaInsertMode = overlays.lastOverlayMode
            sheet = .media
        case .addText, .addGraphic, .addCommentCard, .styleAllTexts, .editText: performTextAction(action)
        case .deleteAllCaptions: captions.deleteAllCaptions()
        case .findInCaptions: captions.openCaptionFind()
        case .editByText:
            toolMenu = nil
            panel = nil
            clips.transcriptSelection = nil
            sheet = .transcript
        case .writeCaptionsByHand:
            toolMenu = nil
            captions.writeCaptionsByHand()
        case .openMusic, .replaceMusic: openMusicSheet(replacing: action == .replaceMusic)
        case .openCoverStudio: cover.openCoverStudio()
        default: break
        }
    }

    /// The menus and panels a button opens. False when `action` isn't one of them.
    private func performOpening(_ action: EditorAction) -> Bool {
        switch action {
        case .openMenu(let menu):
            selection = nil
            toolMenu = menu
        case .openCaptions: openCaptions()
        case .open(let panel): open(panel)
        case .openLook(let tool, let wholeVideo): openLook(tool, wholeVideo: wholeVideo)
        case .openSmart(let section): openSmart(on: section)
        default: return false
        }
        return true
    }

    /// A panel from the toolbar. A video over the take without sound has no Volume to open, and says so.
    private func open(_ panel: EditorPanel) {
        if panel == .volume, selectedMedia?.kind == .video, selectedMedia?.hasSound == false {
            toast.show(String(localized: "This video has no sound"), kind: .problem)
            return
        }
        look.lookScopeIsClip = panel.hasClipScope && selection?.clipID != nil
        self.panel = panel
    }

    /// Adjust, Skin, Filters or Background at the reach the button says: the picked clip's own (its bar), or the whole video's
    /// (the main bar, and an item's badged shortcut, whatever is picked). Skin is Adjust opened on Skin Smoothing.
    private func openLook(_ tool: EditorLookTool, wholeVideo: Bool) {
        look.lookScopeIsClip = !wholeVideo && selection?.clipID != nil
        look.lookTool = tool
        if tool == .skin { look.adjustOpensOn = .skinSmoothing }
        panel = tool.panel
    }

    /// ✦ Smart on `section` (Templates and Brand kit straight on theirs), also when Smart is already open.
    private func openSmart(on section: SmartPanelSection) {
        smartSection = section
        panel = .smart
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
        if performOnClip(action) || performOnMotion(action) || performOnMedia(action) || performOnBlur(action) { return true }
        switch action {
        case .duplicateText: selection?.textID.map(overlays.duplicateText)
        case .toggleLock: toggleLockOfSelection()
        case .deleteText: selection?.textID.map(overlays.deleteText)
        case .editCaption:
            panel = .captions
            captions.focusesCaptionField = true
        case .emphasizeCaption:
            captions.expandedLineID = selection?.captionID
            panel = .captions
        case .splitCaption: selection?.captionID.map(captions.splitCaptionAtPlayhead)
        case .joinCaption: selection?.captionID.map(captions.joinCaption)
        case .deleteCaption: selection?.captionID.map(captions.deleteCaptionLine)
        case .deleteMusic: selection?.musicID.map(audio.deleteMusic)
        case .reRecordVoiceOver: selection?.voiceOverID.map(audio.reRecordVoiceOver)
        case .deleteVoiceOver: selection?.voiceOverID.map(audio.deleteVoiceOver)
        default: return false
        }
        return true
    }

    /// The actions on a picked photo or video. False when `action` isn't one of them.
    private func performOnMedia(_ action: EditorAction) -> Bool {
        guard let id = selection?.mediaID else { return false }
        switch action {
        case .duplicateMedia: overlays.duplicateMedia(id)
        case .replaceMedia: replaceSelectedMedia()
        case .deleteMedia: overlays.deleteMedia(id)
        case .splitMedia: overlays.splitMedia(id)
        case .closeGap: overlays.closeGap(before: id)
        case .saveMediaToLibrary: Task { await brand.saveMediaToLibrary(id) }
        case .openMask:
            if let media = selectedMedia, let reason = overlays.maskUnavailableReason(media) {
                toast.show(reason, kind: .problem)
            } else {
                panel = .mask
            }
        case .openSplitTab(let tab):
            panel = .media
            panelTab = tab
        case .swapSplit:
            overlays.swapSplit()
            sayUndoable(String(localized: "Places swapped"))
        case .openMediaMotion: panel = .motion
        default: return false
        }
        return true
    }

    /// Blur area: adding one (from anywhere), and the picked one's tools. False when `action` isn't one of them.
    private func performOnBlur(_ action: EditorAction) -> Bool {
        switch action {
        case .addBlurArea: blur.startAdding(onMainVideo: isSplitMainAreaPicked)
        case .followBlur: blur.follow()
        case .reviewBlur: blur.review()
        case .deleteBlur: selectedBlurID.map(blur.delete)
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

    /// The actions on a clip: the picked one, or from the main bar the one under the playhead. False when `action` isn't one of
    /// them.
    private func performOnClip(_ action: EditorAction) -> Bool {
        switch action {
        case .splitClip: clips.splitClip()
        case .duplicateClip: pickClipForAction().map(clips.duplicateClip)
        case .reorderClips: clips.openClipOrder()
        case .freezeFrame: startJob { await self.clips.freezeFrame() }
        case .reverseClip:
            // One at a time: a second tap never stops the first.
            if !jobs.isRunning(.reverse) { jobs.start(.reverse) { [weak self] _ in await self?.clips.reverseClip() } }
        case .replaceClip:
            pickClipForAction()
            clips.askToReplaceClip()
        case .extractAudio:
            // A video over the take extracts its own sound; anything else, a clip's.
            if selection?.mediaID == nil { pickClipForAction() }
            startJob { await self.audio.extractAudio() }
        case .copyLook:
            pickClipForAction()
            look.copyClipLook()
        case .pasteLook:
            if look.canPasteLook { pickClipForAction() }
            look.askToPasteLook()
        case .deleteClip: selection?.clipID.map(clips.deleteClip)
        default: return false
        }
        return true
    }

    /// From the main bar (no clip picked) a clip action that works on a picked clip first picks the one under the playhead, so
    /// it has its clip and its tools show; on a clip's bar, the picked one. The clip's id.
    @discardableResult
    private func pickClipForAction() -> UUID? {
        if selection?.clipID == nil { clips.selectClipAtPlayhead() }
        return selection?.clipID
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
