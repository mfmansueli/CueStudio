//
//  ClipSource+Script.swift
//  Cue Studio
//

import Foundation

/// The script a montage's other recording was read from: the one kept when it was added, or its take's (a recording added
/// before that was kept); none for a video brought in. Captions and Clean up hear each recording with its own script.
extension ClipSource {
    @MainActor
    func script(takes: TakeLibraryService, library: ScriptLibraryService) -> Script? {
        scriptReference ?? takeID
            .flatMap { id in takes.takes.first { $0.id == id } }
            .flatMap { $0.captionScript(current: library.script(id: $0.scriptID)) }
    }
}
