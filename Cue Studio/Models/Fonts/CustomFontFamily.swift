//
//  CustomFontFamily.swift
//  Cue Studio
//

import Foundation

/// A family the creator imported (one file or several: Regular, Bold…), named by its family name, which is how videos,
/// saved styles and brand kits refer to it (`TextOverlayFont.custom`). Removed, it leaves the pickers but stays on this
/// iPhone while anything still uses it (`CustomFontStore.sweepRemoved`).
nonisolated struct CustomFontFamily: Codable, Identifiable, Hashable, Sendable {
    var name: String
    var faces: [CustomFontFace]
    var importedAt: Date
    /// Taken out of the pickers by the creator; its files go once nothing names the family.
    var isRemoved = false

    var id: String { name }

    var font: TextOverlayFont { .custom(name) }

    /// The editor weights it draws, lightest first.
    var weights: [TextOverlayWeight] {
        let upright = faces.filter { !$0.isItalic }
        let drawn = Set((upright.isEmpty ? faces : upright).flatMap(\.editorWeights))
        return TextOverlayWeight.editorWeights.filter { drawn.contains($0) }
    }

    /// The face that draws `weight`: an upright one first, the nearest in weight (a variable face whose axis reaches it wins).
    func face(for weight: TextOverlayWeight) -> CustomFontFace? {
        let upright = faces.filter { !$0.isItalic }
        let candidates = upright.isEmpty ? faces : upright
        if let variable = candidates.first(where: { $0.weightRange?.contains(weight.value) == true }) { return variable }
        return candidates.min { abs($0.weight - weight.value) < abs($1.weight - weight.value) }
    }

    /// "Regular, Bold · 2 files".
    var summary: String {
        let styles = faces.map(\.styleName).joined(separator: ", ")
        return String(localized: "\(styles) · \(faces.count) files", comment: "An imported font family: its styles and how many files it came in")
    }
}
