//
//  EditorToolbarTool.swift
//  Cue Studio
//

import Foundation

/// A tool of the main bar, also offered on the picked items' bars after their own tools: one identity (`id`, never a localized
/// word), one icon and one action wherever it shows, so the same tool never shows twice on a bar and reads the same on every
/// one. Whether it can work right now (dimmed) and its badge are the bar's to say (`QuickEditViewModel.item(_:)`).
enum EditorToolbarTool: CaseIterable, Hashable {
    // The basics
    case edit, split, captions, text, media, audio
    // Editing the clip under the playhead
    case speed, volume, zoom, stabilize, freeze, reverse, duplicate, replace, reorder, crop, animation
    // Speech and sound
    case pauses, editByText, studioVoice, extractAudio, autoEdit
    // Picture and beauty (the whole video's look)
    case format, adjust, skin, filters, background, blurArea, copyLook, pasteLook
    // Finishing
    case templates, brandKit, cover
    /// From another item's bar: the tools of the clip under the playhead.
    case clip

    var id: String {
        switch self {
        case .edit: "edit"
        case .split: "split"
        case .captions: "captions"
        case .text: "text"
        case .media: "addMedia"
        case .audio: "audio"
        case .speed: "speed"
        case .volume: "volume"
        case .zoom: "zoom"
        case .stabilize: "stabilize"
        case .freeze: "freeze"
        case .reverse: "reverse"
        case .duplicate: "duplicate"
        case .replace: "replace"
        case .reorder: "reorder"
        case .crop: "clipCrop"
        case .animation: "clipAnimation"
        case .pauses: "pauses"
        case .editByText: "editByText"
        case .studioVoice: "voice"
        case .extractAudio: "extractAudio"
        case .autoEdit: "autoEdit"
        case .format: "format"
        case .adjust: EditorLookTool.adjust.toolbarID(wholeVideo: true)
        case .skin: EditorLookTool.skin.toolbarID(wholeVideo: true)
        case .filters: EditorLookTool.filters.toolbarID(wholeVideo: true)
        case .background: EditorLookTool.background.toolbarID(wholeVideo: true)
        case .blurArea: "blurArea"
        case .copyLook: "copyLook"
        case .pasteLook: "pasteLook"
        case .templates: "templates"
        case .brandKit: "brandKit"
        case .cover: "cover"
        case .clip: "clipTools"
        }
    }

    var label: String {
        switch self {
        case .edit: String(localized: "Edit")
        case .split: String(localized: "Split")
        case .captions: String(localized: "Captions")
        case .text: String(localized: "Text")
        case .media: String(localized: "Media")
        case .audio: String(localized: "Audio")
        case .speed: String(localized: "Speed")
        case .volume: String(localized: "Volume")
        case .zoom: String(localized: "Zoom")
        case .stabilize: String(localized: "Stabilize")
        case .freeze: String(localized: "Freeze frame")
        case .reverse: String(localized: "Reverse")
        case .duplicate: String(localized: "Duplicate")
        case .replace: String(localized: "Replace")
        case .reorder: String(localized: "Reorder")
        case .crop: String(localized: "Crop")
        case .animation: String(localized: "Animation")
        case .pauses: String(localized: "Clean up", comment: "Editor tool: the speech clean-up (pauses, ums and repeats, edit by text); Portuguese \"Limpar fala\"")
        case .editByText: String(localized: "Edit by text")
        case .studioVoice: String(localized: "Studio Voice")
        case .extractAudio: String(localized: "Extract audio")
        case .autoEdit: String(localized: "Auto edit")
        case .format: String(localized: "Aspect ratio")
        case .adjust: EditorLookTool.adjust.label
        case .skin: EditorLookTool.skin.label
        case .filters: EditorLookTool.filters.label
        case .background: EditorLookTool.background.label
        case .blurArea: String(localized: "Blur area")
        case .copyLook: String(localized: "Copy look")
        case .pasteLook: String(localized: "Paste look")
        case .templates: TemplatesPanelSection.templates.label
        case .brandKit: TemplatesPanelSection.brand.label
        case .cover: String(localized: "Cover")
        case .clip: String(localized: "Clip")
        }
    }

    var systemImage: String {
        switch self {
        case .edit: "scissors"
        case .split: "arrow.left.and.line.vertical.and.arrow.right"
        case .captions: "captions.bubble"
        case .text: "textformat"
        case .media: "photo.badge.plus"
        case .audio: "music.note"
        case .speed: "gauge.with.dots.needle.67percent"
        case .volume: "speaker.wave.2"
        case .zoom: "plus.magnifyingglass"
        case .stabilize: "camera.metering.center.weighted"
        case .freeze: "pause.rectangle"
        case .reverse: "backward.end.alt"
        case .duplicate: "plus.square.on.square"
        case .replace: "arrow.left.arrow.right"
        case .reorder: "arrow.up.arrow.down"
        case .crop: "crop.rotate"
        case .animation: "rectangle.portrait.and.arrow.forward"
        case .pauses: "rectangle.compress.vertical"
        case .editByText: "text.badge.minus"
        case .studioVoice: "waveform.and.mic"
        case .extractAudio: "waveform.badge.plus"
        case .autoEdit: "wand.and.stars"
        case .format: "aspectratio"
        case .adjust: EditorLookTool.adjust.systemImage
        case .skin: EditorLookTool.skin.systemImage
        case .filters: EditorLookTool.filters.systemImage
        case .background: EditorLookTool.background.systemImage
        case .blurArea: "eye.slash"
        case .copyLook: "doc.on.doc"
        case .pasteLook: "doc.on.clipboard"
        case .templates: "rectangle.stack"
        case .brandKit: "r.circle"
        case .cover: "photo.artframe"
        case .clip: "film"
        }
    }

    var action: EditorAction {
        switch self {
        case .edit, .clip: .selectClipAtPlayhead
        case .split: .splitClip
        case .captions: .openCaptions
        case .text: .openMenu(.text)
        case .media: .openMenu(.media)
        case .audio: .openMenu(.audio)
        case .speed: .open(.speed)
        case .volume: .open(.volume)
        case .zoom: .open(.zoom)
        case .stabilize: .open(.stabilize)
        case .freeze: .freezeFrame
        case .reverse: .reverseClip
        case .duplicate: .duplicateClip
        case .replace: .replaceClip
        case .reorder: .reorderClips
        case .crop: .open(.clipCrop)
        case .animation: .open(.clipAnimation)
        case .pauses: .open(.pauses)
        case .editByText: .editByText
        case .studioVoice: .open(.voice)
        case .extractAudio: .extractAudio
        case .autoEdit: .openAutoEdit
        case .format: .open(.crop)
        case .adjust: .openLook(.adjust, wholeVideo: true)
        case .skin: .openLook(.skin, wholeVideo: true)
        case .filters: .openLook(.filters, wholeVideo: true)
        case .background: .openLook(.background, wholeVideo: true)
        case .blurArea: .addBlurArea
        case .copyLook: .copyLook
        case .pasteLook: .pasteLook
        case .templates: .openTemplates(.templates)
        case .brandKit: .openTemplates(.brand)
        case .cover: .openCoverStudio
        }
    }

    /// A clip's bar has a tool with the same name for that clip alone, so the main bar says this one is the whole video's.
    var hasClipVersion: Bool {
        switch self {
        case .adjust, .skin, .filters, .background: true
        default: false
        }
    }

    /// What it changes reaches past a picked item: on an item's bar it carries the whole video's badge.
    var reachesWholeVideo: Bool {
        switch self {
        case .captions, .pauses, .autoEdit, .editByText, .studioVoice, .format, .adjust, .skin, .filters, .background, .templates, .brandKit: true
        default: false
        }
    }
}
