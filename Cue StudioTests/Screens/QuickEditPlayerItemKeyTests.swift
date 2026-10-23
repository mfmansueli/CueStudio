//
//  QuickEditPlayerItemKeyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The preview builds a new item exactly when what it plays changes (`QuickEditPlayer.ItemKey`): every part of a clip that
/// changes the picture or the sound is in the key, so a new part of `EditSegment` fails here until the key reads it (or it
/// is listed as not changing the item).
@MainActor
@Suite("Quick edit: the preview's item follows every clip setting")
struct QuickEditPlayerItemKeyTests {
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
        let before = QuickEditPlayer.ItemKey(edit)
        for (part, change) in Self.changes {
            var changed = edit
            var segment = changed.timeline.segments[2]
            change(&segment)
            let replaced = changed.timeline.replaceSegment(segment)
            try #require(replaced)
            #expect(QuickEditPlayer.ItemKey(changed) != before, "Changing \(part) left the preview playing the old clip")
        }
    }

    @Test func swappingClipsOfTheSameSecondsOfOtherRecordingsMakesANewItem() {
        var edit = Self.montage()
        let before = QuickEditPlayer.ItemKey(edit)
        _ = edit.timeline.moveSegment(from: 2, to: 3)
        #expect(edit.timeline.segments.map(\.span) == Self.montage().timeline.segments.map(\.span))
        #expect(QuickEditPlayer.ItemKey(edit) != before)
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
}
