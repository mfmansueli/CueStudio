//
//  EditorPanel.swift
//  Cue Studio
//

import Foundation

/// A panel that opens under the timeline in place of the toolbar. Its ✓ applies and closes it;
/// changes show live in the preview.
enum EditorPanel: String, CaseIterable, Identifiable {
    // The selected clip
    case speed, zoom, volume, stabilize, clipCrop, clipAnimation
    // The whole take
    case voice, pauses, adjust, skin, filters, crop, background
    // Captions
    case captions, autoCaptions, captionStyle
    // Texts
    case textStyle
    // Audio
    case voiceOver, beats, voiceEffects
    // Added on top: a photo or video over the take, its mask and its motion
    case media, mask, motion
    // Blur area: a face, a plate, a name hidden
    case blur
    // The cut between two clips
    case transition
    // Templates and the creator's brand kits
    case templates

    var id: String { rawValue }

    var size: EditorPanelSize {
        switch self {
        case .zoom, .volume, .filters, .voiceOver, .autoCaptions: .mini
        case .speed, .voice, .pauses, .captions, .adjust, .skin, .background, .media, .templates, .transition, .crop, .stabilize, .beats: .medium
        case .voiceEffects: .medium
        case .clipCrop, .clipAnimation: .medium
        case .mask, .blur, .motion: .medium
        case .textStyle, .captionStyle: .full
        }
    }

    /// The styling panels can be expanded, giving their controls the room the video gives up, and so can Clean up (its Text
    /// tab reads the whole take), in place, at its own height otherwise.
    var isExpandable: Bool { size == .full || self == .pauses }

    /// The panels with many rows to scroll (the styling ones, and Background with its green screen's settings): their content stops further
    /// above the Home Indicator and fades under it while it scrolls.
    var scrollsClearOfHomeIndicator: Bool { isExpandable || self == .background }

    /// Panels about one track bring it up under the ruler.
    var focusedLane: TimelineLane? {
        switch self {
        case .textStyle: .text
        case .captions, .captionStyle, .autoCaptions: .captions
        case .voiceOver: .voiceOver
        case .media, .mask, .motion: .media
        case .blur: .blur
        default: nil
        }
    }

    /// Panels that work on the selected item close when it's let go.
    var followsSelection: Bool {
        switch self {
        case .speed, .zoom, .volume, .stabilize, .clipCrop, .clipAnimation, .beats, .textStyle, .media, .mask, .motion, .blur, .transition: true
        case .voiceEffects: true
        default: false
        }
    }

    /// The clip panels: opened with nothing picked (from the main toolbar), they pick the clip under the playhead for as long as
    /// they're open, so moving the playhead never moves the change to another clip.
    var pinsClip: Bool {
        switch self {
        case .speed, .zoom, .volume, .stabilize, .clipCrop, .clipAnimation, .voiceEffects: true
        default: false
        }
    }

    /// The panels that change the take's look, or one clip's when opened from a picked clip.
    var hasClipScope: Bool {
        switch self {
        case .adjust, .skin, .filters, .background: true
        default: false
        }
    }

    /// Whether the panel works on `selection` (a panel that follows the selection closes when
    /// something it can't work on is picked).
    func accepts(_ selection: EditorSelection) -> Bool {
        switch self {
        case .speed, .zoom, .stabilize, .clipCrop, .clipAnimation: selection.clipID != nil
        case .volume: selection.clipID != nil || selection.musicID != nil || selection.voiceOverID != nil || selection.mediaID != nil
        case .textStyle: selection.textID != nil
        case .media, .mask, .motion: selection.mediaID != nil
        // Choosing what to hide on a photo or video over the take keeps it picked meanwhile.
        case .blur: selection.blurID != nil || selection.mediaID != nil
        case .beats: selection.musicID != nil
        case .voiceEffects: selection.clipID != nil || selection.voiceOverID != nil
        case .transition: selection.joinID != nil
        default: true
        }
    }

    var title: String {
        switch self {
        case .speed: String(localized: "Speed")
        case .zoom: String(localized: "Zoom")
        case .stabilize: String(localized: "Stabilize")
        case .clipCrop: String(localized: "Crop")
        case .clipAnimation: String(localized: "Animation")
        case .volume: String(localized: "Volume")
        case .voice: String(localized: "Studio Voice")
        case .pauses: String(localized: "Clean up")
        case .adjust: String(localized: "Adjust")
        case .skin: EditorLookTool.skin.label
        case .filters: String(localized: "Filters")
        case .crop: String(localized: "Aspect ratio")
        case .background: String(localized: "Background")
        case .captions: String(localized: "Captions")
        case .autoCaptions: String(localized: "Auto captions")
        case .captionStyle: String(localized: "Caption style")
        case .textStyle: String(localized: "Text")
        case .voiceOver: String(localized: "Voice-over")
        case .beats: String(localized: "Beats")
        case .voiceEffects: String(localized: "Voice effects")
        case .media: String(localized: "Photo or video")
        case .mask: String(localized: "Mask")
        case .motion: String(localized: "Motion")
        case .blur: String(localized: "Blur area")
        case .transition: String(localized: "Transition")
        case .templates: String(localized: "Templates")
        }
    }
}
