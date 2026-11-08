//
//  BrandKitPart.swift
//  Cue Studio
//

import Foundation

/// A part of a brand kit the creator chooses to put on a video.
nonisolated enum BrandKitPart: String, CaseIterable, Identifiable, Hashable, Sendable {
    case textStyle, captionStyle, coverStyle, fonts, colors, logo, editing, studioVoice, zoom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .textStyle: String(localized: "Text style")
        case .captionStyle: String(localized: "Caption style")
        case .coverStyle: String(localized: "Cover style")
        case .fonts: String(localized: "Fonts")
        case .colors: String(localized: "Colors")
        case .logo: String(localized: "Logo")
        case .editing: String(localized: "Editing", comment: "A brand kit's part: how the creator cleans up a video and starts its music")
        case .studioVoice: String(localized: "Studio Voice")
        case .zoom: String(localized: "Zoom")
        }
    }

    var systemImage: String {
        switch self {
        case .textStyle: "textformat"
        case .captionStyle: "captions.bubble"
        case .coverStyle: "photo.artframe"
        case .fonts: "textformat.characters"
        case .colors: "paintpalette"
        case .logo: "seal"
        case .editing: "slider.horizontal.3"
        case .studioVoice: "waveform"
        case .zoom: "plus.magnifyingglass"
        }
    }
}
