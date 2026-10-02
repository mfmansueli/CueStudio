//
//  EditorPanel.swift
//  Cue Studio
//

import Foundation

/// A panel that opens under the timeline in place of the toolbar. Its ✓ applies and closes it;
/// changes show live in the preview.
enum EditorPanel: String, CaseIterable, Identifiable {
    // The selected clip
    case speed, zoom, volume
    // The whole take
    case voice, pauses, adjust, filters, crop, background, cover
    // Captions
    case captions, autoCaptions, captionStyle
    // Texts
    case textStyle
    // Audio
    case voiceOver
    // Added on top: a photo or video over the take
    case media
    // The cut between two clips
    case transition

    var id: String { rawValue }

    var size: EditorPanelSize {
        switch self {
        case .speed, .zoom, .volume, .filters, .crop, .voiceOver, .autoCaptions, .media, .transition: .mini
        case .voice, .pauses, .captions, .adjust, .background, .cover: .medium
        case .textStyle, .captionStyle: .full
        }
    }

    /// Panels about one track bring it up under the ruler.
    var focusedLane: TimelineLane? {
        switch self {
        case .textStyle: .text
        case .captions, .captionStyle, .autoCaptions: .captions
        case .voiceOver: .voiceOver
        default: nil
        }
    }

    /// Panels that work on the selected item close when it's let go.
    var followsSelection: Bool {
        switch self {
        case .speed, .zoom, .volume, .textStyle, .media, .transition: true
        default: false
        }
    }

    /// The panels that change the take's look, or one clip's when opened from a picked clip.
    var hasClipScope: Bool {
        switch self {
        case .adjust, .filters, .background: true
        default: false
        }
    }

    /// Whether the panel works on `selection` (a panel that follows the selection closes when
    /// something it can't work on is picked).
    func accepts(_ selection: EditorSelection) -> Bool {
        switch self {
        case .speed, .zoom: selection.clipID != nil
        case .volume: selection.clipID != nil || selection.musicID != nil || selection.voiceOverID != nil
        case .textStyle: selection.textID != nil
        case .media: selection.mediaID != nil
        case .transition: false
        default: true
        }
    }

    var title: String {
        switch self {
        case .speed: String(localized: "Speed")
        case .zoom: String(localized: "Zoom")
        case .volume: String(localized: "Volume")
        case .voice: String(localized: "Voice")
        case .pauses: String(localized: "Pauses")
        case .adjust: String(localized: "Adjust")
        case .filters: String(localized: "Filters")
        case .crop: String(localized: "Crop")
        case .background: String(localized: "Background")
        case .cover: String(localized: "Cover")
        case .captions: String(localized: "Captions")
        case .autoCaptions: String(localized: "Auto captions")
        case .captionStyle: String(localized: "Caption style")
        case .textStyle: String(localized: "Text")
        case .voiceOver: String(localized: "Voice-over")
        case .media: String(localized: "Photo or video")
        case .transition: String(localized: "Transition")
        }
    }
}
