//
//  TakeEdit+MissingMedia.swift
//  Cue Studio
//

import Foundation

/// The files an edit names that are no longer on the iPhone (`EditMediaFiles`), and the edit without them. Exported as it is, each would leave
/// a gap nobody chose: a montage clip played as black, a photo or a sound left out without a word. So the review asks before exporting and the
/// editor says so when it opens (decision of the owner, 01/11/2026: never a silent black frame).
nonisolated extension TakeEdit {
    func missingMedia(exists: (String) -> Bool = EditMediaFiles.exists) -> Set<String> {
        mediaFileNames.filter { !exists($0) }
    }

    /// Taking `missing` out leaves nothing that names them: false when every clip plays a recording that's gone (only replacing one helps).
    func canDropMedia(_ missing: Set<String>) -> Bool {
        withoutMedia(missing).mediaFileNames.isDisjoint(with: missing)
    }

    /// This edit without what names `missing`: its photos and videos on top, voice-overs, music and sounds, a background's photo (the
    /// background back to the original), the cover's photo (the cover back to a frame of the video) and the montage's clips of a recording
    /// that's gone, all but the last clip (an edit always plays something: then it is for the editor to replace).
    func withoutMedia(_ missing: Set<String>) -> TakeEdit {
        guard !missing.isEmpty else { return self }
        var edit = self
        edit.media.removeAll { missing.contains($0.fileName) }
        edit.voiceOvers.removeAll { missing.contains($0.fileName) }
        edit.music.removeAll { missing.contains($0.fileName) }
        for index in edit.backgrounds.indices {
            guard let name = edit.backgrounds[index].effect.imageFileName, missing.contains(name) else { continue }
            edit.backgrounds[index].effect.imageFileName = nil
            edit.backgrounds[index].effect.style = .original
        }
        edit.timeline = edit.timeline.withoutBackgroundPhotos(missing)
        if case .photo(let name)? = edit.cover?.source, missing.contains(name) {
            edit.cover = nil
        } else if case .photo(let name)? = edit.cover?.composition?.split?.source, missing.contains(name) {
            edit.cover?.composition?.split = nil
        }
        let gone = Set(edit.sources.filter { missing.contains($0.fileName) }.map(\.id))
        for segment in edit.timeline.segments where segment.sourceID.map(gone.contains) == true {
            edit.timeline.removeSegment(id: segment.id)
        }
        edit.sources.removeAll { source in gone.contains(source.id) && !edit.timeline.segments.contains { $0.sourceID == source.id } }
        return edit
    }
}
