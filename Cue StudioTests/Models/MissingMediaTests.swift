//
//  MissingMediaTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// B10: files an edit names that are gone from the iPhone are found before an export, and taking them out leaves an edit that names
/// none of them, never a black stretch or a silent gap nobody chose.
@MainActor
@Suite("Missing media")
struct MissingMediaTests {
    /// Every kind of file an edit can name, with `gone` the ones no longer on the iPhone.
    private func edit() -> TakeEdit {
        var edit = EditFixtures.blank()
        edit.media = [
            MediaOverlay(kind: .photo, fileName: "photo.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 0, end: 2)),
            MediaOverlay(kind: .photo, fileName: "logo.png", aspect: 2, mediaDuration: nil, span: TimeSpan(start: 0, end: 4)),
        ]
        edit.voiceOvers = [VoiceOverClip(fileName: "voice.m4a", duration: 3, anchor: 0)]
        edit.music = [MusicClip(fileName: "song.m4a", title: "Loop", fileDuration: 60, start: 0, length: 10)]
        edit.backgrounds = [RecordingBackground(sourceID: nil, effect: BackgroundEffect(style: .image, imageFileName: "beach.jpg"))]
        edit.cover = VideoCover(source: .photo(fileName: "cover.jpg"))
        let walk = ClipSource(fileName: "walk.mov", duration: 10, title: "Walk")
        edit.sources = [walk]
        edit.timeline.insertClip(source: walk.id, duration: 10)
        return edit
    }

    @Test func onlyWhatIsGoneIsFound() {
        let gone: Set = ["photo.jpg", "walk.mov", "beach.jpg"]
        #expect(edit().missingMedia { !gone.contains($0) } == gone)
        #expect(edit().missingMedia { _ in true }.isEmpty)
    }

    @Test func removingWhatIsGoneLeavesTheRestAsItWas() {
        let gone: Set = ["photo.jpg", "voice.m4a", "song.m4a", "beach.jpg", "cover.jpg", "walk.mov"]
        let original = edit()
        #expect(original.canDropMedia(gone))
        let kept = original.withoutMedia(gone)
        #expect(kept.mediaFileNames == ["logo.png"])
        #expect(kept.media.map(\.fileName) == ["logo.png"])
        #expect(kept.voiceOvers.isEmpty && kept.music.isEmpty)
        #expect(kept.backgrounds.first?.effect.style == .original)
        #expect(kept.cover == nil)
        #expect(kept.sources.isEmpty)
        #expect(kept.timeline.segments.count == 1 && kept.timeline.segments[0].sourceID == nil, "the take's own recording still plays")
        #expect(original.withoutMedia([]) == original)
    }

    /// A clip's own background photo goes back to the edit's background, and a montage made only of a recording that's gone keeps its
    /// last clip: removing can't fix it, only Replace can.
    @Test func aClipsBackgroundGoesAndALoneClipNeedsReplacing() {
        var edit = EditFixtures.blank()
        let walk = ClipSource(fileName: "walk.mov", duration: 10, title: "Walk")
        edit.sources = [walk]
        edit.timeline.insertClip(source: walk.id, duration: 10)
        let take = edit.timeline.segments.first { $0.sourceID == nil }?.id
        edit.timeline.removeSegment(id: take ?? UUID())
        #expect(!edit.canDropMedia(["walk.mov"]))
        #expect(edit.withoutMedia(["walk.mov"]).timeline.segments.count == 1)

        var look = ClipLook()
        look.background = BackgroundEffect(style: .image, imageFileName: "sky.jpg")
        var withLook = EditFixtures.blank()
        withLook.timeline.insertClip(source: walk.id, duration: 10, look: look)
        withLook.sources = [walk]
        #expect(withLook.mediaFileNames.contains("sky.jpg"))
        #expect(!withLook.withoutMedia(["sky.jpg"]).mediaFileNames.contains("sky.jpg"))
    }

    /// The editor says what's gone as it opens, and Remove takes it out as one step Undo takes back.
    @Test func removingInTheEditorIsOneStep() {
        let document = EditDocument(edit())
        document.changeEdit { $0 = $0.withoutMedia(["photo.jpg"]) }
        #expect(!document.edit.mediaFileNames.contains("photo.jpg"))
        #expect(document.undo())
        #expect(document.edit.mediaFileNames.contains("photo.jpg"))
    }
}
