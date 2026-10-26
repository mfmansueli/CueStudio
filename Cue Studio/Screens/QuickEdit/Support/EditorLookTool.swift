//
//  EditorLookTool.swift
//  Cue Studio
//

import Foundation

/// The picture's tools a button opens, each at the reach the button says (the whole video, or the picked clip): Adjust, Skin
/// (Adjust opened on Skin Smoothing: the same panel, a destination of its own), Filters and Background. While its panel is open
/// it also says which fields "Use this on all" counts and clears (`LookViewModel.lookTool`).
enum EditorLookTool: Hashable {
    case adjust, skin, filters, background

    /// The panel it opens.
    var panel: EditorPanel {
        switch self {
        case .adjust, .skin: .adjust
        case .filters: .filters
        case .background: .background
        }
    }

    var label: String {
        switch self {
        case .adjust: String(localized: "Adjust")
        case .skin: String(localized: "Skin", comment: "Video editor toolbar: opens Adjust on Skin Smoothing (softens the skin of faces)")
        case .filters: String(localized: "Filters")
        case .background: String(localized: "Background")
        }
    }

    var systemImage: String {
        switch self {
        case .adjust: "slider.horizontal.3"
        case .skin: "face.smiling"
        case .filters: "camera.filters"
        case .background: "person.and.background.dotted"
        }
    }

    /// `edit.toolbar.<id>`: the clip's own tool keeps the plain id, the whole video's "…Video" (Filters keeps "filters" on both,
    /// as it always had).
    func toolbarID(wholeVideo: Bool) -> String {
        switch self {
        case .adjust: wholeVideo ? "adjustVideo" : "adjust"
        case .skin: wholeVideo ? "skinVideo" : "skin"
        case .filters: "filters"
        case .background: wholeVideo ? "backgroundVideo" : "background"
        }
    }
}
