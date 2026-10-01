//
//  QuickEditViewModel+Toolbar.swift
//  Cue Studio
//

import Foundation

/// The toolbar by context: the main tools with nothing picked; the picked item's own tools (Clip,
/// Text, Caption, Music, Voice-over, Media) with a yellow "‹" back to the main ones; and the Text
/// and Audio menus. Speed and Zoom stay two separate tools.
extension QuickEditViewModel {
    /// The name next to the back button; nil on the main toolbar.
    var toolbarContextLabel: String? {
        selection?.contextLabel ?? toolMenu?.contextLabel
    }

    var toolbarItems: [EditorToolbarItem] {
        if let selection { return items(for: selection) }
        switch toolMenu {
        case .text: return textMenuItems
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

    private var mainItems: [EditorToolbarItem] {
        [
            EditorToolbarItem(id: "edit", label: String(localized: "Edit"), systemImage: "scissors", action: .selectClipAtPlayhead),
            EditorToolbarItem(id: "text", label: String(localized: "Text"), systemImage: "textformat", action: .openMenu(.text)),
            EditorToolbarItem(id: "captions", label: String(localized: "Captions"), systemImage: "captions.bubble", action: .openCaptions),
            EditorToolbarItem(id: "audio", label: String(localized: "Audio"), systemImage: "music.note", action: .openMenu(.audio)),
            EditorToolbarItem(id: "pauses", label: String(localized: "Pauses"), systemImage: "waveform", action: .open(.pauses)),
            EditorToolbarItem(id: "media", label: String(localized: "Media"), systemImage: "photo.badge.plus", action: .addMedia),
            EditorToolbarItem(id: "adjust", label: String(localized: "Adjust"), systemImage: "slider.horizontal.3", action: .open(.adjust)),
            EditorToolbarItem(id: "filters", label: String(localized: "Filters"), systemImage: "camera.filters", action: .open(.filters)),
            EditorToolbarItem(
                id: "background", label: String(localized: "Background"), systemImage: "person.and.background.dotted", action: .open(.background)
            ),
            EditorToolbarItem(id: "crop", label: String(localized: "Crop"), systemImage: "crop", action: .open(.crop)),
        ]
    }

    private var textMenuItems: [EditorToolbarItem] {
        var items = [
            EditorToolbarItem(id: "title", label: String(localized: "Title"), systemImage: "textformat.size.larger", action: .addText(.title)),
            EditorToolbarItem(id: "subtitle", label: String(localized: "Subtitle"), systemImage: "text.alignleft", action: .addText(.subtitle)),
            EditorToolbarItem(id: "hook", label: String(localized: "Hook"), systemImage: "bolt", action: .addText(.hook)),
            EditorToolbarItem(id: "callout", label: String(localized: "Callout"), systemImage: "text.bubble", action: .addText(.callout)),
        ]
        if !edit.texts.isEmpty {
            items.append(EditorToolbarItem(id: "styleAll", label: String(localized: "Style all"), systemImage: "square.grid.2x2", action: .styleAllTexts))
        }
        return items
    }

    private var audioMenuItems: [EditorToolbarItem] {
        [
            EditorToolbarItem(id: "voice", label: String(localized: "Voice"), systemImage: "waveform.and.mic", action: .open(.voice)),
            EditorToolbarItem(id: "music", label: String(localized: "Music"), systemImage: "music.note", action: .openMusic),
            EditorToolbarItem(id: "voiceOver", label: String(localized: "Voice-over"), systemImage: "mic", action: .open(.voiceOver)),
        ]
    }

    private func items(for selection: EditorSelection) -> [EditorToolbarItem] {
        let delete = String(localized: "Delete")
        switch selection {
        case .clip:
            return [
                EditorToolbarItem(
                    id: "split", label: String(localized: "Split"), systemImage: "arrow.left.and.line.vertical.and.arrow.right",
                    style: canSplitSelectedClip ? .normal : .dimmed, action: .splitClip
                ),
                EditorToolbarItem(id: "speed", label: String(localized: "Speed"), systemImage: "gauge.with.dots.needle.67percent", action: .open(.speed)),
                EditorToolbarItem(id: "zoom", label: String(localized: "Zoom"), systemImage: "arrow.up.left.and.arrow.down.right", action: .open(.zoom)),
                EditorToolbarItem(id: "volume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", action: .open(.volume)),
                EditorToolbarItem(id: "voice", label: String(localized: "Voice"), systemImage: "waveform.and.mic", action: .open(.voice)),
                EditorToolbarItem(id: "duplicate", label: String(localized: "Duplicate"), systemImage: "plus.square.on.square", action: .duplicateClip),
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteClip),
            ]
        case .text:
            return [
                EditorToolbarItem(id: "editText", label: String(localized: "Edit"), systemImage: "pencil", action: .editText),
                EditorToolbarItem(id: "style", label: String(localized: "Style"), systemImage: "textformat.alt", action: .open(.textStyle)),
                EditorToolbarItem(id: "keyframe", label: String(localized: "Keyframe"), systemImage: "diamond", action: .toggleKeyframe),
                EditorToolbarItem(id: "duplicate", label: String(localized: "Duplicate"), systemImage: "plus.square.on.square", action: .duplicateText),
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
        case .music:
            return [
                EditorToolbarItem(id: "volume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", action: .open(.volume)),
                EditorToolbarItem(id: "replace", label: String(localized: "Replace"), systemImage: "arrow.left.arrow.right", action: .replaceMusic),
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteMusic),
            ]
        case .voiceOver:
            return [
                EditorToolbarItem(id: "volume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", action: .open(.volume)),
                EditorToolbarItem(id: "reRecord", label: String(localized: "Re-record"), systemImage: "mic.badge.plus", action: .reRecordVoiceOver),
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteVoiceOver),
            ]
        case .media:
            return [
                EditorToolbarItem(id: "editMedia", label: String(localized: "Edit"), systemImage: "pencil", action: .open(.media)),
                EditorToolbarItem(id: "delete", label: delete, systemImage: "trash", style: .destructive, action: .deleteMedia),
            ]
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
        case .open(let panel): self.panel = panel
        case .addMedia:
            mediaInsertMode = .overlay
            sheet = .media
        case .addText(let role): addStyledText(role)
        case .styleAllTexts: styleAllTexts()
        case .editText:
            panel = .textStyle
            focusesTextField = true
        case .openMusic:
            if let first = edit.music.first {
                selection = .music(first.id)
            } else {
                sheet = .music
            }
        case .replaceMusic: sheet = .music
        default: break
        }
    }

    /// The actions on the picked item. False when `action` isn't one of them.
    private func performOnSelection(_ action: EditorAction) -> Bool {
        switch action {
        case .splitClip: splitClip()
        case .duplicateClip: selection?.clipID.map(duplicateClip)
        case .deleteClip: selection?.clipID.map(deleteClip)
        case .toggleKeyframe: toggleKeyframe()
        case .duplicateText: selection?.textID.map(duplicateText)
        case .deleteText: selection?.textID.map(deleteText)
        case .editCaption: panel = .captions
        case .splitCaption: selection?.captionID.map(splitCaptionAtPlayhead)
        case .joinCaption: selection?.captionID.map(joinCaption)
        case .deleteCaption: selection?.captionID.map(deleteCaptionLine)
        case .deleteMusic: selection?.musicID.map(deleteMusic)
        case .reRecordVoiceOver: selection?.voiceOverID.map(reRecordVoiceOver)
        case .deleteVoiceOver: selection?.voiceOverID.map(deleteVoiceOver)
        case .deleteMedia: selection?.mediaID.map(deleteMedia)
        default: return false
        }
        return true
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
        textStyleScope = .allTexts
        panel = .textStyle
    }
}
