//
//  QuickEditViewModel+MainToolbar.swift
//  Cue Studio
//

import Foundation

/// The main toolbar (nothing picked) and the menus it opens. Every tool the editor has is on it, grouped by what they work on
/// (owner's decision, 26/10/2026, after InShot's one long bar), in the picked clip's order so a tool sits among the same ones
/// on both bars (owner, 28/10/2026): the basics, the five on screen with ✦ Smart fifth; the clip under the playhead's essentials;
/// its picture; the montage; the whole video, the cover last. A clip tool works on the clip under the playhead without picking
/// it first (`QuickEditViewModel+Toolbar`).
extension QuickEditViewModel {
    /// The groups of the main bar, a thin line between them.
    static let mainToolGroups: [[EditorToolbarTool]] = [
        [.edit, .split, .captions, .text, .smart, .media, .audio],
        [.speed, .volume, .zoom],
        [.adjust, .skin, .filters, .background, .crop, .stabilize, .blurArea, .copyLook, .pasteLook],
        [.animation, .duplicate, .freeze, .reverse, .replace, .reorder, .extractAudio],
        [.editByText, .pauses, .studioVoice, .format, .templates, .brandKit, .cover],
    ]

    var mainItems: [EditorToolbarItem] {
        Self.grouped(Self.mainToolGroups.map { $0.map { item($0) } })
    }

    /// `tool` as a button: dimmed where it can't work right now (a tap still says why). Nothing here reads the playhead, so the
    /// bar never redraws while the video plays (Split on the main bar says at the tap when the playhead is too close to a cut).
    func item(_ tool: EditorToolbarTool) -> EditorToolbarItem {
        let style: EditorToolbarItem.Style = switch tool {
        case .smart: .smart
        case .reorder: edit.timeline.segments.count > 1 ? .normal : .dimmed
        case .pasteLook: look.canPasteLook ? .normal : .dimmed
        default: .normal
        }
        return EditorToolbarItem(id: tool.id, label: tool.label, systemImage: tool.systemImage, style: style, action: tool.action)
    }

    /// Groups as one bar: the first tool of every group after the first starts it with a thin line; empty groups go.
    static func grouped(_ groups: [[EditorToolbarItem]]) -> [EditorToolbarItem] {
        var items: [EditorToolbarItem] = []
        for group in groups where !group.isEmpty {
            items += group.enumerated().map { index, item in index == 0 && !items.isEmpty ? item.startingGroup() : item }
        }
        return items
    }

    // MARK: - Menus

    var textMenuItems: [EditorToolbarItem] {
        var items = [
            EditorToolbarItem(id: "title", label: String(localized: "Title"), systemImage: "textformat.size.larger", action: .addText(.title)),
            EditorToolbarItem(
                id: "subtitle", label: TextOverlayRole.subtitle.label, systemImage: TextOverlayRole.subtitle.systemImage, action: .addText(.subtitle)
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
        // The kit's fonts and colors on every text.
        items.append(item(.brandKit).startingGroup())
        return items
    }

    /// The ways to add a photo or video (the sheet's cards), each opening the gallery on it, Your library and the brand kit (its
    /// logo).
    var mediaMenuItems: [EditorToolbarItem] {
        let ways: [(id: String, mode: MediaInsertMode)] = [
            ("mediaSplit", .split), ("mediaWindow", .window), ("mediaFullScreen", .fullScreen), ("mediaSequence", .sequence),
        ]
        return ways.map { way in
            EditorToolbarItem(id: way.id, label: way.mode.label, systemImage: way.mode.systemImage, action: .addMediaAs(way.mode))
        } + [
            EditorToolbarItem(
                id: "mediaLibrary", label: String(localized: "Your library"), systemImage: "tray.full", action: .addMediaFromLibrary,
                startsGroup: true
            ),
            item(.brandKit),
        ]
    }

    /// An area over a face (the faces in the frame to tap), or one drawn; Compare shows the video without them while it's on.
    var blurMenuItems: [EditorToolbarItem] {
        [
            EditorToolbarItem(id: "blurFace", label: String(localized: "Blur area"), systemImage: "eye.slash", action: .addBlurArea),
            EditorToolbarItem(id: "blurDraw", label: String(localized: "Draw an area"), systemImage: "rectangle.dashed", action: .drawBlurArea),
            EditorToolbarItem(
                id: "blurCompare", label: String(localized: "Compare"), systemImage: "circle.lefthalf.filled", action: .compareBlur,
                startsGroup: true, isOn: blur.comparesOriginal
            ),
        ]
    }

    /// With lines: Show (the panel's switch), add one, the list, the style, Translate, and, after a line, Delete all (no line is
    /// picked here: nothing takes Delete's pinned place, and it asks first). Without: make them, or write them.
    var captionsMenuItems: [EditorToolbarItem] {
        if edit.captions.isEmpty {
            return [
                EditorToolbarItem(id: "autoCaptions", label: String(localized: "Auto captions"), systemImage: "captions.bubble", action: .openCaptions),
                EditorToolbarItem(
                    id: "writeCaptions", label: String(localized: "Write captions"), systemImage: "pencil", action: .writeCaptionsByHand
                ),
                item(.editByText),
            ]
        }
        return [
            EditorToolbarItem(
                id: "showCaptions", label: String(localized: "Show"), systemImage: edit.showsCaptions ? "eye" : "eye.slash",
                action: .toggleCaptionsShown, isOn: edit.showsCaptions
            ),
            EditorToolbarItem(id: "addLine", label: String(localized: "Add line"), systemImage: "plus.bubble", action: .addCaptionLine),
            EditorToolbarItem(id: "allLines", label: String(localized: "All lines"), systemImage: "list.bullet", action: .openCaptions),
            EditorToolbarItem(id: "style", label: String(localized: "Style"), systemImage: "textformat.alt", action: .open(.captionStyle)),
            EditorToolbarItem(
                id: "translate", label: captions.captionTranslationLabel, systemImage: "translate", action: .openCaptionTranslation
            ),
            EditorToolbarItem(
                id: "findReplace", label: String(localized: "Find and replace"), systemImage: "text.magnifyingglass", action: .findInCaptions
            ),
            item(.editByText),
            EditorToolbarItem(
                id: "deleteAll", label: String(localized: "Delete all"), systemImage: "xmark.bin", style: .destructiveAll,
                action: .deleteAllCaptions, startsGroup: true
            ),
        ]
    }

    /// The voice, music, sound effects, voice-over and a voice-over spoken from text; then the clip under the playhead's sound:
    /// its volume, a voice effect on it, or on a track of its own.
    var audioMenuItems: [EditorToolbarItem] {
        [
            item(.studioVoice),
            EditorToolbarItem(id: "music", label: String(localized: "Music"), systemImage: "music.note", action: .openMusic),
            EditorToolbarItem(id: "soundEffects", label: String(localized: "Sound effects"), systemImage: "speaker.wave.2.bubble", action: .openSoundEffects),
            EditorToolbarItem(id: "voiceOver", label: String(localized: "Voice-over"), systemImage: "mic", action: .open(.voiceOver)),
            EditorToolbarItem(id: "textToSpeech", label: String(localized: "Text to speech"), systemImage: "text.bubble", action: .openTextToSpeech),
            item(.volume).startingGroup(),
            EditorToolbarItem(
                id: "voiceEffects", label: String(localized: "Voice effects"), systemImage: "waveform.badge.magnifyingglass", action: .open(.voiceEffects)
            ),
            item(.extractAudio),
        ]
    }
}
