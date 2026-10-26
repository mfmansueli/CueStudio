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

    /// The tool a look panel is when nothing says otherwise (Adjust is Adjust, not Skin).
    init?(panel: EditorPanel) {
        switch panel {
        case .adjust: self = .adjust
        case .filters: self = .filters
        case .background: self = .background
        default: return nil
        }
    }

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

    /// Whether a clip's own look sets what this tool changes, so the whole video's value doesn't reach it: Adjust, any of its
    /// dials or Auto (Skin Smoothing included, it's one of Adjust's); Skin, Skin Smoothing only; Filters, the filter or its
    /// amount; Background, the background.
    func isOwn(in look: ClipLook) -> Bool {
        switch self {
        case .adjust: look.overridesAdjustment
        case .skin: look.skinSmoothing != nil
        case .filters: look.filter != nil || look.filterAmount != nil
        case .background: look.background != nil
        }
    }

    /// Gives a clip the whole video's value again for what this tool changes, and nothing else of its own.
    func clear(_ look: inout ClipLook) {
        switch self {
        case .adjust: look.removeAdjustment()
        case .skin: look.skinSmoothing = nil
        case .filters: look.removeFilter()
        case .background: look.removeBackground()
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
