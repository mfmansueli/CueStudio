//
//  QuickEditViewModel+ItemToolbar.swift
//  Cue Studio
//

import Foundation

/// A picked item's toolbar: its own tools first, as they always were (the four on screen are the ones a creator uses most on it),
/// then, after a thin line, the editor's other tools, so any of them is reached without going back to the main bar (owner's
/// decision, 26/10/2026): Captions, Text, Media, Audio and ✦ Smart first. A tool that changes the whole video carries the
/// "All" badge, and none that would read as the item's own is added (no Split, Speed, Volume or Zoom of the video next to
/// a text), nor one the item's tools already reach. Delete stays pinned at the end (`EditorToolbarItem.isPinned`).
extension QuickEditViewModel {
    /// What a clip's bar adds after its own tools (owner, 28/10/2026): what goes on top of it, then everything that changes the
    /// whole video, together, so no "All" sits among the clip's own.
    static let clipShortcutGroups: [[EditorToolbarTool]] = [
        [.text, .media, .audio, .smart],
        [.editByText, .pauses, .studioVoice, .captions, .format, .templates, .brandKit, .cover],
    ]

    /// What every other item's bar adds: the clip under the playhead's tools first.
    static let itemShortcutGroups: [[EditorToolbarTool]] = [
        [.clip],
        [.captions, .text, .media, .audio, .smart],
        [.pauses, .editByText],
        [.format, .adjust, .skin, .filters, .background, .blurArea],
        [.templates, .brandKit, .cover],
    ]

    func items(for selection: EditorSelection) -> [EditorToolbarItem] {
        let delete = String(localized: "Delete")
        switch selection {
        case .clip:
            return withShortcuts(clipItems, Self.clipShortcutGroups, delete: deleteItem(delete, .deleteClip))
        case .text:
            let own = [
                EditorToolbarItem(id: "editText", label: String(localized: "Edit"), systemImage: "pencil", action: .editText),
                EditorToolbarItem(id: "style", label: String(localized: "Style"), systemImage: "textformat.alt", action: .open(.textStyle)),
                EditorToolbarItem(id: "animation", label: String(localized: "Motion"), systemImage: "wind", action: .openTextAnimation),
                EditorToolbarItem(id: "keyframe", label: String(localized: "Keyframe"), systemImage: "diamond", action: .toggleKeyframe),
                EditorToolbarItem(id: "track", label: String(localized: "Track"), systemImage: "scope", action: .trackItem),
                EditorToolbarItem(id: "duplicate", label: String(localized: "Duplicate"), systemImage: "plus.square.on.square", action: .duplicateText),
                lockItem,
            ]
            return withShortcuts(own, Self.itemShortcutGroups, delete: deleteItem(delete, .deleteText))
        case .caption:
            let own = [
                EditorToolbarItem(id: "editCaption", label: String(localized: "Edit"), systemImage: "pencil", action: .editCaption),
                EditorToolbarItem(
                    id: "split", label: String(localized: "Split"), systemImage: "arrow.left.and.line.vertical.and.arrow.right", action: .splitCaption
                ),
                EditorToolbarItem(
                    id: "join", label: String(localized: "Join next"), systemImage: "arrow.right.and.line.vertical.and.arrow.left", action: .joinCaption
                ),
                EditorToolbarItem(id: "emphasis", label: String(localized: "Emphasis"), systemImage: "highlighter", action: .emphasizeCaption),
                EditorToolbarItem(id: "style", label: String(localized: "Style"), systemImage: "textformat.alt", action: .open(.captionStyle)),
            ]
            // Edit already opens the Captions panel on this line: Captions would open the same list.
            return withShortcuts(own, Self.itemShortcutGroups, leaving: [.captions], delete: deleteItem(delete, .deleteCaption))
        case .music(let id):
            // Beats for the creator's music from Files, not for a sound effect or a sound taken out of the video.
            let isMusic = edit.music.first { $0.id == id }.map { !$0.followsTheVideo } ?? false
            var own = [EditorToolbarItem(id: "volume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", action: .open(.volume))]
            if isMusic { own.append(EditorToolbarItem(id: "beats", label: String(localized: "Beats"), systemImage: "metronome", action: .open(.beats))) }
            own += [
                EditorToolbarItem(id: "replace", label: String(localized: "Replace"), systemImage: "arrow.left.arrow.right", action: .replaceMusic),
                lockItem,
            ]
            return withShortcuts(own, Self.itemShortcutGroups, delete: deleteItem(delete, .deleteMusic))
        case .voiceOver:
            let own = [
                EditorToolbarItem(id: "volume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", action: .open(.volume)),
                EditorToolbarItem(id: "reRecord", label: String(localized: "Re-record"), systemImage: "mic.badge.plus", action: .reRecordVoiceOver),
                lockItem,
            ]
            return withShortcuts(own, Self.itemShortcutGroups, delete: deleteItem(delete, .deleteVoiceOver))
        case .media:
            guard let media = selectedMedia else { return [] }
            if media.layout == .split, overlays.selectedArea == .main {
                // No Delete here: with the creator's face outlined, it would remove the support.
                return withShortcuts(mainAreaItems, Self.itemShortcutGroups, delete: nil)
            }
            let own = media.layout == .split ? supportItems(media) : overlayItems(media)
            return withShortcuts(own, Self.itemShortcutGroups, delete: deleteItem(delete, .deleteMedia))
        case .blur:
            let own = [
                EditorToolbarItem(id: "editBlur", label: String(localized: "Edit"), systemImage: "pencil", action: .open(.blur)),
                EditorToolbarItem(id: "followBlur", label: String(localized: "Track"), systemImage: "scope", action: .followBlur),
                EditorToolbarItem(id: "reviewBlur", label: String(localized: "Replay"), systemImage: "play.rectangle", action: .reviewBlur),
                EditorToolbarItem(id: "addBlur", label: String(localized: "Add area"), systemImage: "plus.viewfinder", action: .addBlurArea),
            ]
            return withShortcuts(own, Self.itemShortcutGroups, delete: deleteItem(delete, .deleteBlur))
        case .join:
            // A cut is picked only with its Transition panel open, which takes the toolbar's place.
            return []
        }
    }

    // MARK: - Own tools

    /// A clip's own tools in three groups (owner, 28/10/2026): its essentials, the five on screen; its picture; the montage, ending
    /// with Reset clip. Mute and Mirror are switches, lit while on.
    private var clipItems: [EditorToolbarItem] {
        var split = item(.split)
        split.style = clips.canSplitSelectedClip ? .normal : .dimmed
        let isMuted = targetClip?.isMuted ?? false
        let essentials = [
            split,
            item(.speed),
            item(.volume),
            EditorToolbarItem(
                id: "mute", label: String(localized: "Mute"), systemImage: isMuted ? "speaker.slash.fill" : "speaker.slash",
                action: .toggleClipMute, isOn: isMuted
            ),
            item(.zoom),
        ]
        let picture = [EditorLookTool.adjust, .skin, .filters, .background].map(clipLookItem) + [
            item(.crop),
            EditorToolbarItem(
                id: "mirror", label: String(localized: "Mirror"), systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                action: .toggleClipMirror, isOn: targetClip?.isMirrored ?? false
            ),
            item(.stabilize),
            item(.blurArea),
            item(.copyLook),
            item(.pasteLook),
        ]
        let montage = [
            EditorToolbarItem(
                id: "transition", label: String(localized: "Transition"), systemImage: "square.split.diagonal.2x2",
                style: edit.timeline.segments.count > 1 ? .normal : .dimmed, action: .openClipTransition
            ),
            item(.animation),
            item(.duplicate),
            item(.freeze),
            item(.reverse),
            item(.replace),
            item(.reorder),
            item(.extractAudio),
            EditorToolbarItem(
                id: "resetClip", label: String(localized: "Reset clip"), systemImage: "arrow.counterclockwise",
                style: clips.canResetClip ? .normal : .dimmed, action: .resetClip
            ),
        ]
        return Self.grouped([essentials, picture, montage])
    }

    /// Adjust, Skin, Filters or Background of the picked clip.
    private func clipLookItem(_ tool: EditorLookTool) -> EditorToolbarItem {
        EditorToolbarItem(
            id: tool.toolbarID(wholeVideo: false), label: tool.label, systemImage: tool.systemImage, action: .openLook(tool, wholeVideo: false)
        )
    }

    /// The main video's area of a split screen (tapping the creator's area): its framing, the two contents' places and layout, the
    /// clip under the playhead's tools, and hiding something on it.
    private var mainAreaItems: [EditorToolbarItem] {
        [
            EditorToolbarItem(id: "framing", label: EditorPanelTab.framing.label, systemImage: "crop", action: .openSplitTab(.framing)),
            EditorToolbarItem(id: "swap", label: String(localized: "Swap places"), systemImage: "arrow.up.arrow.down", action: .swapSplit),
            EditorToolbarItem(id: "layout", label: EditorPanelTab.layout.label, systemImage: "rectangle.split.1x2", action: .openSplitTab(.layout)),
            item(.clip),
            item(.blurArea),
        ]
    }

    /// A support of the split screen: what a react or a tutorial changes most, on screen (its layout, its sound, swapping the two
    /// contents, another video in its place), then its part, cutting it, hiding something on it, its gap.
    private func supportItems(_ media: MediaOverlay) -> [EditorToolbarItem] {
        var items = [
            EditorToolbarItem(id: "layout", label: EditorPanelTab.layout.label, systemImage: "rectangle.split.1x2", action: .openSplitTab(.layout)),
            EditorToolbarItem(id: "sound", label: EditorPanelTab.sound.label, systemImage: "speaker.wave.2", action: .openSplitTab(.sound)),
            EditorToolbarItem(id: "swap", label: String(localized: "Swap places"), systemImage: "arrow.up.arrow.down", action: .swapSplit),
            EditorToolbarItem(id: "replaceMedia", label: String(localized: "Replace"), systemImage: "arrow.left.arrow.right", action: .replaceMedia),
            EditorToolbarItem(id: "part", label: EditorPanelTab.part.label, systemImage: "film", action: .openSplitTab(.part)),
            EditorToolbarItem(
                id: "splitMedia", label: String(localized: "Split"), systemImage: "arrow.left.and.line.vertical.and.arrow.right", action: .splitMedia
            ),
            item(.blurArea),
        ]
        if overlays.gapBefore(media.id) != nil {
            items.append(EditorToolbarItem(id: "closeGap", label: String(localized: "Close gap"), systemImage: "arrow.left.to.line", action: .closeGap))
        }
        return items + sharedMediaItems
    }

    /// A photo or video in a window or over the whole frame: its panel, its sound and motion and mask on screen, then cutting,
    /// replacing, hiding something on it, Track and keyframes (as a text has them), a copy.
    private func overlayItems(_ media: MediaOverlay) -> [EditorToolbarItem] {
        var items = [EditorToolbarItem(id: "editMedia", label: String(localized: "Edit"), systemImage: "pencil", action: .open(.media))]
        if media.kind == .video {
            // A video without sound says so when tapped.
            items.append(EditorToolbarItem(
                id: "mediaVolume", label: String(localized: "Volume"), systemImage: "speaker.wave.2", style: media.hasSound == false ? .dimmed : .normal,
                action: .open(.volume)
            ))
        }
        items += [
            EditorToolbarItem(id: "mediaMotion", label: String(localized: "Motion"), systemImage: "wind", action: .openMediaMotion),
            EditorToolbarItem(id: "mask", label: String(localized: "Mask"), systemImage: "circle.rectangle.dashed", action: .openMask),
            EditorToolbarItem(
                id: "splitMedia", label: String(localized: "Split"), systemImage: "arrow.left.and.line.vertical.and.arrow.right", action: .splitMedia
            ),
            EditorToolbarItem(id: "replaceMedia", label: String(localized: "Replace"), systemImage: "arrow.left.arrow.right", action: .replaceMedia),
            item(.blurArea),
            EditorToolbarItem(id: "track", label: String(localized: "Track"), systemImage: "scope", action: .trackItem),
            EditorToolbarItem(id: "keyframe", label: String(localized: "Keyframe"), systemImage: "diamond", action: .toggleKeyframe),
            EditorToolbarItem(id: "duplicate", label: String(localized: "Duplicate"), systemImage: "plus.square.on.square", action: .duplicateMedia),
        ]
        return items + sharedMediaItems
    }

    /// What every photo or video ends with: the library, its sound taken out (a video with sound), Lock.
    private var sharedMediaItems: [EditorToolbarItem] {
        var items = [
            EditorToolbarItem(
                id: "saveToLibrary", label: String(localized: "Save to library"), systemImage: "tray.and.arrow.down", action: .saveMediaToLibrary
            ),
        ]
        // Only a video with a sound of its own has one to take out.
        if audio.canExtractAudio { items.append(item(.extractAudio)) }
        items.append(lockItem)
        return items
    }

    /// Lock or Unlock for the picked layer.
    private var lockItem: EditorToolbarItem {
        selectionIsLocked
            ? EditorToolbarItem(id: "unlock", label: String(localized: "Unlock"), systemImage: "lock.open", action: .toggleLock)
            : EditorToolbarItem(id: "lock", label: String(localized: "Lock"), systemImage: "lock", action: .toggleLock)
    }

    private func deleteItem(_ label: String, _ action: EditorAction) -> EditorToolbarItem {
        EditorToolbarItem(id: "delete", label: label, systemImage: "trash", style: .destructive, action: action)
    }

    // MARK: - Shortcuts

    /// `own`, then the shortcut `groups` (each after a thin line) without the ones in `leaving`, the ones whose action the own
    /// tools already have, or an id already on the bar; then Delete.
    private func withShortcuts(
        _ own: [EditorToolbarItem], _ groups: [[EditorToolbarTool]], leaving: Set<EditorToolbarTool> = [], delete: EditorToolbarItem?
    ) -> [EditorToolbarItem] {
        let actions = Set(own.map(\.action))
        var ids = Set(own.map(\.id))
        if let delete { ids.insert(delete.id) }
        let shortcuts = groups.map { group in
            group.filter { tool in !leaving.contains(tool) && !actions.contains(tool.action) && !ids.contains(tool.id) }.map { tool in
                let item = item(tool)
                return tool.reachesWholeVideo ? item.reachingWholeVideo() : item
            }
        }
        return Self.grouped([own] + shortcuts) + (delete.map { [$0] } ?? [])
    }
}
