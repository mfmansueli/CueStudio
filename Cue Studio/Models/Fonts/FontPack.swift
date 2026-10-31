//
//  FontPack.swift
//  Cue Studio
//

import Foundation

/// A family of a script's library (`FontPackManifest`): free fonts (SIL OFL) from Google Fonts, never in the app, each file
/// downloaded the first time a video needs it (`FontPackStore`). A text or caption that uses one saves it as
/// "pack:<id>" (`TextOverlayFont.pack`); a caption style finds the one with its own character (`ScriptTypeMap`).
nonisolated struct FontPack: Codable, Hashable, Identifiable, Sendable {
    /// One file of the family (`FontPackFile`).
    typealias File = FontPackFile

    var id: String
    /// The family's name, as Google Fonts writes it.
    var family: String
    var script: WritingScript
    var character: TypeCharacter
    /// "OFL".
    var licence: String
    var copyright: String
    var files: [File]

    /// The editor weights the family draws, lightest first.
    var weights: [TextOverlayWeight] {
        let drawn = Set(files.flatMap(\.editorWeights))
        return TextOverlayWeight.editorWeights.filter { drawn.contains($0) }
    }

    /// The file that draws `weight`: a variable one whose axis reaches it, else the cut nearest it (the heavier of two).
    func file(for weight: TextOverlayWeight) -> File {
        if let variable = files.first(where: { $0.weightRange?.contains(weight.value) == true }) { return variable }
        let target = weight == .heavy ? 850 : weight.value
        return files.min { abs($0.weight - target) - $0.weight / 10_000 < abs($1.weight - target) - $1.weight / 10_000 } ?? files[0]
    }

    /// What every file of the family weighs together, in bytes.
    var bytes: Int { files.reduce(0) { $0 + $1.bytes } }
}
