//
//  CompositionShapeTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// Two builds of an edit with the same pieces on the same tracks have the same shape, so the
/// preview keeps its item for them; new pieces or a new speed don't.
@Suite("CompositionShape", .serialized, .timeLimit(.minutes(2)))
struct CompositionShapeTests {
    private func shape(of edit: TakeEdit, clip: URL) async throws -> CompositionShape? {
        let built = try await EditedComposition.build(
            source: clip, edit: edit, processedAudio: nil, options: .init(burnsInCaptions: true, shortSide: 1080)
        )
        return CompositionShape(of: built.asset)
    }

    @Test func aLookTextOrVolumeKeepsTheShapeAndNewPiecesChangeIt() async throws {
        let clip = try await TestClip.make(seconds: 3, loudSeconds: [0, 1, 2])
        defer { try? FileManager.default.removeItem(at: clip) }
        var edit = TakeEdit(sourceDuration: 3, aspect: .portrait)
        edit.timeline.split(atEdited: 1)
        edit.timeline.split(atEdited: 2)
        let original = try #require(try await shape(of: edit, clip: clip))

        var looked = edit
        looked.filter = .mono
        looked.exposure = 40
        var title = TextOverlay(role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: TimeSpan(start: 0, end: 2))
        title.text = "Hello"
        looked.texts = [title]
        var quieter = looked.timeline.segments[1]
        quieter.volume = 0.3
        _ = looked.timeline.replaceSegment(quieter)
        #expect(try await shape(of: looked, clip: clip) == original)

        var removed = edit
        removed.timeline.removeSegment(id: removed.timeline.segments[1].id)
        #expect(try await shape(of: removed, clip: clip) != original)

        var faster = edit
        _ = faster.timeline.setSpeed(1.5, forSegmentAt: 1)
        #expect(try await shape(of: faster, clip: clip) != original)
    }

    @Test func aFileHasNoShape() async throws {
        let clip = try await TestClip.make(seconds: 1)
        defer { try? FileManager.default.removeItem(at: clip) }
        #expect(CompositionShape(of: AVURLAsset(url: clip)) == nil)
    }
}
