//
//  RenderPlanTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What a drawing reads (`RenderPlan`), and the preview's item built again exactly when what it plays changes
/// (`RenderPlan.Item`): every part of a clip that changes the picture or the sound is in the item, so a new part of
/// `EditSegment` fails here until the plan reads it (or it is listed as not changing the item).
@MainActor
@Suite("The render plan, and the preview's item following every clip setting")
struct RenderPlanTests {
    /// Parts of a clip the item never depends on: a split gives new identities to the same picture.
    private static let notPlayed: Set<String> = ["id"]

    /// How each part of the clip in the middle (the third) is changed here.
    private static let changes: [String: (inout EditSegment) -> Void] = [
        "sourceStart": { $0.sourceStart = 3 },
        "sourceEnd": { $0.sourceEnd = 7 },
        "transitionIn": { $0.transitionIn = .push },
        "transitionDuration": { $0.transitionDuration = 0.8 },
        "speed": { $0.speed = 2 },
        "speedCurve": { $0.speedCurve = SpeedCurve(points: [.init(position: 0, speed: 0.5), .init(position: 1, speed: 2)]) },
        "sourceID": { $0.sourceID = UUID() },
        "zoom": { $0.zoom = .pushIn },
        "zoomAmount": { $0.zoomAmount = 0.9 },
        "volume": { $0.volume = 0.5 },
        "isMuted": { $0.isMuted = true },
        "keepsPitch": { $0.keepsPitch = false },
        "look": { segment in
            var look = ClipLook()
            look.filter = .cinema
            segment.look = look
        },
        "stabilization": { $0.stabilization = .strong },
    ]

    @Test func everyPartOfAClipIsReadOrListed() {
        let parts = Set(Mirror(reflecting: Self.montage().timeline.segments[2]).children.compactMap(\.label))
        #expect(parts == Set(Self.changes.keys).union(Self.notPlayed), "A part of EditSegment isn't in ItemKey's tests")
    }

    @Test func changingAnyPartOfAClipMakesANewItem() throws {
        let edit = Self.montage()
        let before = Self.item(edit)
        for (part, change) in Self.changes {
            var changed = edit
            var segment = changed.timeline.segments[2]
            change(&segment)
            let replaced = changed.timeline.replaceSegment(segment)
            try #require(replaced)
            #expect(Self.item(changed) != before, "Changing \(part) left the preview playing the old clip")
        }
    }

    @Test func swappingClipsOfTheSameSecondsOfOtherRecordingsMakesANewItem() {
        var edit = Self.montage()
        let before = Self.item(edit)
        _ = edit.timeline.moveSegment(from: 2, to: 3)
        #expect(edit.timeline.segments.map(\.span) == Self.montage().timeline.segments.map(\.span))
        #expect(Self.item(edit) != before)
    }

    /// A trim usually only moves the window the item plays (the handles scrub without a rebuild), but a zoomed first clip's
    /// zoom runs over the clip as made, so trimming it is a new item; and the transitions are measured on the edit as made.
    @Test func trimmingAZoomedFirstClipMakesANewItemAndAPlainOneDoesnt() throws {
        var plain = TakeEdit(sourceDuration: 20, aspect: .portrait)
        let before = Self.item(plain)
        plain.timeline.trimStart(to: 2)
        #expect(Self.item(plain) == before)
        var zoomed = TakeEdit(sourceDuration: 20, aspect: .portrait)
        var clip = try #require(zoomed.timeline.segments.first)
        clip.zoom = .pushIn
        _ = zoomed.timeline.replaceSegment(clip)
        let zoomedBefore = Self.item(zoomed)
        zoomed.timeline.trimStart(to: 2)
        #expect(Self.item(zoomed) != zoomedBefore)
    }

    /// Trimming the start only moves the window the item plays, unless a look counts its grain from there: then the grain
    /// would run from the wrong moment, so the item is new.
    @Test func trimmingTheStartUnderAGrainyFilterMakesANewItem() {
        var clean = TakeEdit(sourceDuration: 20, aspect: .portrait)
        clean.filter = .cinema
        let cleanBefore = Self.item(clean)
        clean.timeline.trimStart(to: 2)
        #expect(Self.item(clean) == cleanBefore)
        var grainy = TakeEdit(sourceDuration: 20, aspect: .portrait)
        grainy.filter = .warmFilm
        let grainyBefore = Self.item(grainy)
        grainy.timeline.trimStart(to: 2)
        #expect(Self.item(grainy) != grainyBefore)
    }

    /// The preview draws the edit grown to the whole recording and plays it from where the edit starts; an export draws the
    /// edit as it is, from its start, with music over all of it.
    @Test func thePreviewGrowsTheEditAndTheExportDrawsItAsItIs() throws {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.timeline.trimStart(to: 3)
        edit.timeline.trimEnd(to: 15)
        let preview = RenderPlan(edit, purpose: .editorPreview(rendersCurveSound: true))
        #expect(preview.drawn.timeline.segments.first?.sourceStart == 0)
        #expect(preview.drawn.timeline.segments.last?.sourceEnd == 20)
        #expect(preview.leadIn == 3)
        #expect(preview.window == TimeSpan(start: 3, end: 15))
        let export = RenderPlan(edit, purpose: .export(burnsInCaptions: true, shortSide: nil, frameRate: nil))
        #expect(export.drawn == edit)
        #expect(export.leadIn == 0)
        #expect(export.window == nil)
    }

    /// The take, then the same seconds (2 to 8, with room around them for a transition) of three other recordings; the
    /// third clip, the one changed, comes in with a dissolve.
    private static func montage() -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        for title in ["Walk", "Talk", "Run"] {
            let source = ClipSource(fileName: "\(title).mov", duration: 10, title: title)
            edit.sources.append(source)
            edit.timeline.insertClip(source: source.id, duration: 10, span: TimeSpan(start: 2, end: 8))
        }
        _ = edit.timeline.setTransition(.dissolve, atJoin: 2)
        return edit
    }

    private static func item(_ edit: TakeEdit) -> RenderPlan.Item {
        RenderPlan(edit, purpose: .editorPreview(rendersCurveSound: true)).item
    }
}
