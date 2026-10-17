//
//  EditorPanel.swift
//  Cue Studio
//

import Foundation

/// A panel that opens under the timeline in place of the toolbar. Its ✓ applies and closes it;
/// changes show live in the preview.
enum EditorPanel: String, CaseIterable, Identifiable {
    // The selected clip
    case speed, zoom, volume, stabilize
    // The whole take
    case voice, pauses, adjust, filters, crop, background
    // Captions
    case captions, autoCaptions, captionStyle
    // Texts
    case textStyle
    // Audio
    case voiceOver, beats
    // Added on top: a photo or video over the take
    case media
    // The cut between two clips
    case transition
    // ✦ Smart: four quick fixes
    case smart

    var id: String { rawValue }

    var size: EditorPanelSize {
        switch self {
        case .zoom, .volume, .filters, .voiceOver, .autoCaptions: .mini
        case .speed, .voice, .pauses, .captions, .adjust, .background, .media, .smart, .transition, .crop, .stabilize, .beats: .medium
        case .textStyle, .captionStyle: .full
        }
    }

    /// The styling panels can be expanded, giving their controls the room the video gives up.
    var isExpandable: Bool { size == .full }

    /// The panels with many rows to scroll (the styling ones, and Background with its green screen's settings): their content stops further
    /// above the Home Indicator and fades under it while it scrolls.
    var scrollsClearOfHomeIndicator: Bool { isExpandable || self == .background }

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
        case .speed, .zoom, .volume, .stabilize, .beats, .textStyle, .media, .transition: true
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
        case .speed, .zoom, .stabilize: selection.clipID != nil
        case .volume: selection.clipID != nil || selection.musicID != nil || selection.voiceOverID != nil
        case .textStyle: selection.textID != nil
        case .media: selection.mediaID != nil
        case .beats: selection.musicID != nil
        case .transition: false
        default: true
        }
    }

    var title: String {
        switch self {
        case .speed: String(localized: "Speed")
        case .zoom: String(localized: "Zoom")
        case .stabilize: String(localized: "Stabilize")
        case .volume: String(localized: "Volume")
        case .voice: String(localized: "Studio Voice")
        case .pauses: String(localized: "Pauses")
        case .adjust: String(localized: "Adjust")
        case .filters: String(localized: "Filters")
        case .crop: String(localized: "Format")
        case .background: String(localized: "Background")
        case .captions: String(localized: "Captions")
        case .autoCaptions: String(localized: "Auto captions")
        case .captionStyle: String(localized: "Caption style")
        case .textStyle: String(localized: "Text")
        case .voiceOver: String(localized: "Voice-over")
        case .beats: String(localized: "Beats")
        case .media: String(localized: "Photo or video")
        case .transition: String(localized: "Transition")
        case .smart: String(localized: "✦ Smart")
        }
    }
}
