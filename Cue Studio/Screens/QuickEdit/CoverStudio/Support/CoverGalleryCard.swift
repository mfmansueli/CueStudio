//
//  CoverGalleryCard.swift
//  Cue Studio
//

import Foundation

/// A card of the Template step, in the row's order: the creator's saved styles, then Cue's templates. "Save style" ends the
/// creator's own styles, and ends the whole row while there are none (the app's one rule for it, as in Caption style and Text).
nonisolated enum CoverGalleryCard: Hashable, Identifiable {
    case saved(UUID)
    case saveStyle
    case template(CoverTemplate)

    var id: String {
        switch self {
        case .saved(let id): "saved.\(id.uuidString)"
        case .saveStyle: "saveStyle"
        case .template(let template): "template.\(template.rawValue)"
        }
    }

    static func gallery(saved: [UUID], templates: [CoverTemplate] = CoverTemplate.allCases) -> [CoverGalleryCard] {
        let mine = saved.map(CoverGalleryCard.saved)
        let cue = templates.map(CoverGalleryCard.template)
        return mine.isEmpty ? cue + [.saveStyle] : mine + [.saveStyle] + cue
    }
}
