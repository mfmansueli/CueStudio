//
//  QuickEditViewModel+MainToolbar.swift
//  Cue Studio
//

import Foundation

/// The main toolbar (nothing picked) and the menus it opens. Every tool the editor has is on it, in the order a talking-head
/// video is made, grouped by what they work on (owner's decision, 26/10/2026, after InShot's one long bar): the basics, the five
/// on screen with ✦ Smart fifth; editing the clip under the playhead; speech and sound; picture and beauty; finishing, the cover
/// last. A clip tool works on the clip under the playhead without picking it first (`QuickEditViewModel+Toolbar`).
extension QuickEditViewModel {
    /// The groups of the main bar, a thin line between them.
    static let mainToolGroups: [[EditorToolbarTool]] = [
        [.edit, .split, .captions, .text, .smart, .media, .audio],
        [.speed, .volume, .zoom, .stabilize, .freeze, .reverse, .duplicate, .replace, .reorder],
        [.pauses, .editByText, .extractAudio],
        [.format, .adjust, .skin, .filters, .background, .blurArea, .copyLook, .pasteLook],
        [.templates, .brandKit, .cover],
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
        return items
    }

    /// With lines: add one, the list, the style. Without: make them, or write them.
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
            EditorToolbarItem(id: "addLine", label: String(localized: "Add line"), systemImage: "plus.bubble", action: .addCaptionLine),
            EditorToolbarItem(id: "allLines", label: String(localized: "All lines"), systemImage: "list.bullet", action: .openCaptions),
            EditorToolbarItem(id: "style", label: String(localized: "Style"), systemImage: "textformat.alt", action: .open(.captionStyle)),
            EditorToolbarItem(
                id: "findReplace", label: String(localized: "Find and replace"), systemImage: "text.magnifyingglass", action: .findInCaptions
            ),
            item(.editByText),
            EditorToolbarItem(
                id: "deleteAll", label: String(localized: "Delete all"), systemImage: "trash", style: .destructive, action: .deleteAllCaptions
            ),
        ]
    }

    var audioMenuItems: [EditorToolbarItem] {
        [
            EditorToolbarItem(id: "voice", label: String(localized: "Studio Voice"), systemImage: "waveform.and.mic", action: .open(.voice)),
            EditorToolbarItem(id: "music", label: String(localized: "Music"), systemImage: "music.note", action: .openMusic),
            EditorToolbarItem(id: "voiceOver", label: String(localized: "Voice-over"), systemImage: "mic", action: .open(.voiceOver)),
        ]
    }
}
