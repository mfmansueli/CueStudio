//
//  SplitScreenModelTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The split screen's numbers: where the areas are for each layout, how a picture fills or fits its area without being
/// stretched, how far it can be moved, where a face is framed, how the main video's sound goes down under a support, and
/// that edits read back whole (and old ones as they were).
@Suite("Split screen model")
struct SplitScreenModelTests {
    private let frame = CGSize(width: 1080, height: 1920)

    // MARK: - Areas

    @Test func theStartingLayoutPutsTheSupportOnTopHalfAndHalf() {
        let areas = SplitPlacement.areas(SplitLayout(), in: frame)
        #expect(areas.support == CGRect(x: 0, y: 0, width: 1080, height: 960))
        #expect(areas.main == CGRect(x: 0, y: 960, width: 1080, height: 960))
        #expect(areas.divider == nil)
    }

    @Test func sixtyFortyGivesTheLargerShareToTheContentPickedWhereverItIs() {
        var layout = SplitLayout(ratio: .sixtyForty, larger: .main)
        var areas = SplitPlacement.areas(layout, in: frame)
        #expect(areas.support.height == 768)
        #expect(areas.main.height == 1152)
        // Swapping moves the contents: the main video goes on top and keeps the larger share.
        layout = layout.swapped
        areas = SplitPlacement.areas(layout, in: frame)
        #expect(areas.main == CGRect(x: 0, y: 0, width: 1080, height: 1152))
        #expect(areas.support == CGRect(x: 0, y: 1152, width: 1080, height: 768))
        layout.larger = .support
        areas = SplitPlacement.areas(layout, in: frame)
        #expect(areas.support.height == 1152)
    }

    @Test func sideBySideSplitsAcrossAndTheAreasMeetWithoutAGap() {
        let layout = SplitLayout(arrangement: .sideBySide, ratio: .sixtyForty, first: .main, larger: .main, showsDivider: true)
        let areas = SplitPlacement.areas(layout, in: CGSize(width: 1081, height: 1920))
        #expect(areas.main.minX == 0)
        #expect(areas.main.maxX == areas.support.minX)
        #expect(areas.support.maxX == 1081)
        #expect(areas.main.width == (1081 * 0.6).rounded())
        #expect(abs((areas.divider?.midX ?? 0) - areas.main.maxX) <= 1)
        #expect(SplitPlacement.seam(layout) == 0.6)
    }

    // MARK: - A picture in its area

    @Test func fillCoversTheAreaFitShowsAllOfItNeitherStretches() {
        let portrait = CGSize(width: 1080, height: 1920)
        let area = CGSize(width: 1080, height: 960)
        let fill = SplitPlacement.place(portrait, in: area, framing: AreaFraming())
        #expect(fill.size.width >= area.width && fill.size.height >= area.height)
        #expect(abs(fill.size.width / fill.size.height - portrait.width / portrait.height) < 0.000_1)
        #expect(fill.origin.y == -480)
        let fit = SplitPlacement.place(portrait, in: area, framing: AreaFraming(fit: .fit))
        #expect(fit.size.height == 960)
        #expect(abs(fit.size.width / fit.size.height - portrait.width / portrait.height) < 0.000_1)
        #expect(fit.origin.x == (1080 - fit.size.width) / 2)
    }

    @Test func aPictureNeverMovesPastItsEdge() {
        let content = CGSize(width: 1080, height: 1920)
        let area = CGSize(width: 1080, height: 960)
        // Its top asked for in the middle: it stops where its top meets the area's.
        let top = SplitPlacement.place(content, in: area, framing: AreaFraming(center: OverlayPoint(x: 0.5, y: 0)))
        #expect(top.origin.y == 0)
        #expect(abs(top.center.y - 0.25) < 0.000_1)
        // A drag further down changes nothing; one up moves it.
        let framing = AreaFraming(center: top.center)
        let down = SplitPlacement.dragged(framing, content: content, area: area, by: CGSize(width: 0, height: 200))
        #expect(abs(down.center.y - 0.25) < 0.000_1)
        let up = SplitPlacement.dragged(framing, content: content, area: area, by: CGSize(width: 0, height: -192))
        #expect(abs(up.center.y - 0.35) < 0.000_1)
        #expect(SplitPlacement.overshoot(framing, content: content, area: area, by: CGSize(width: 0, height: 200)).height == 200)
        #expect(SplitPlacement.overshoot(framing, content: content, area: area, by: CGSize(width: 0, height: -100)).height == 0)
    }

    @Test func zoomStaysInsideItsRange() {
        let content = CGSize(width: 1000, height: 1000)
        let area = CGSize(width: 500, height: 500)
        let wide = SplitPlacement.place(content, in: area, framing: AreaFraming(zoom: 0.2))
        #expect(wide.scale == 0.5)
        let close = SplitPlacement.place(content, in: area, framing: AreaFraming(zoom: 99))
        #expect(close.scale == 2)
    }

    @Test func aFaceIsFramedWithTheEyesAThirdDown() {
        let content = CGSize(width: 1080, height: 1920)
        let area = CGSize(width: 1080, height: 960)
        let face = CGRect(x: 0.4, y: 0.2, width: 0.2, height: 0.12)
        let framing = SplitPlacement.framing(showing: face, content: content, area: area)
        let placed = SplitPlacement.place(content, in: area, framing: framing)
        let eyes = placed.origin.y + CGFloat(face.minY + face.height * 0.4) * placed.size.height
        #expect(abs(eyes - area.height / 3) < 1)
        // No face: the middle, the same every time.
        #expect(SplitPlacement.framing(showing: nil, content: content, area: area) == AreaFraming())
    }

    // MARK: - The main video's sound under a support

    @Test func withoutAWindowTheLevelsStayAsTheyAre() {
        let levels = [EditedComposition.Fade(start: 1, duration: 0.012, fromVolume: 0, toVolume: 1)]
        #expect(MainSoundLevels.scaled(levels, by: []) == levels)
        #expect(MainSoundLevels.scaled(levels, by: [MainSoundLevels.Window(span: TimeSpan(start: 2, end: 3), factor: 1)]) == levels)
    }

    @Test func aWindowTurnsTheMainDownOnlyWhileItLasts() {
        // A clip at 80%, then a cut dip at 5 s.
        let levels = [
            EditedComposition.Fade(start: 0, duration: 0, fromVolume: 0.8, toVolume: 0.8),
            EditedComposition.Fade(start: 5, duration: 0.012, fromVolume: 0, toVolume: 0.8),
        ]
        let scaled = MainSoundLevels.scaled(levels, by: [MainSoundLevels.Window(span: TimeSpan(start: 2, end: 4), factor: 0)])
        #expect(abs(MainSoundLevels.level(scaled, at: 1, before: false) - 0.8) < 0.001)
        #expect(MainSoundLevels.level(scaled, at: 3, before: false) < 0.001)
        #expect(abs(MainSoundLevels.level(scaled, at: 4.5, before: false) - 0.8) < 0.001)
        #expect(MainSoundLevels.level(scaled, at: 5, before: false) < 0.001)
        #expect(abs(MainSoundLevels.level(scaled, at: 6, before: false) - 0.8) < 0.001)
        // Eased in, not a click.
        let halfway = MainSoundLevels.level(scaled, at: 2 + MainSoundLevels.ramp / 2, before: false)
        #expect(halfway > 0.3 && halfway < 0.5)
        // Ramps never overlap.
        let sorted = scaled.sorted { $0.start < $1.start }
        for (one, next) in zip(sorted, sorted.dropFirst()) {
            #expect(one.start + one.duration <= next.start + 0.000_001)
        }
    }

    // MARK: - Reading back

    @Test func anEditWithASplitScreenReadsBackWhole() throws {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        var support = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 16.0 / 9, mediaDuration: 8, span: TimeSpan(start: 1, end: 5))
        support.layout = .split
        support.followsCuts = true
        support.areaFraming = AreaFraming(fit: .fit, zoom: 1.4, center: OverlayPoint(x: 0.3, y: 0.6))
        support.mainVolume = 0.2
        support.audioVolume = 0.7
        edit.media = [support]
        edit.splitScreen.setLayout(SplitLayout(arrangement: .sideBySide, ratio: .sixtyForty, first: .main, larger: .support, showsDivider: true))
        edit.splitScreen.setFraming(AreaFraming(zoom: 2), for: nil)
        edit.splitScreen.mutesMedia = true
        let read = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(read.media == edit.media)
        #expect(read.splitScreen == edit.splitScreen)
    }

    @Test func mediaSavedBeforeReadsAsItWas() throws {
        let media = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 1, mediaDuration: 6, span: TimeSpan(start: 0, end: 2))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(media)) as? [String: Any])
        for key in ["splitLayoutID", "areaFraming", "mainVolume", "followsCuts"] { json[key] = nil }
        let read = try JSONDecoder().decode(MediaOverlay.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(read.followsCuts == nil)
        #expect(read.layout == .fullFrame)
        var edit = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(TakeEdit(sourceDuration: 4, aspect: .portrait))) as? [String: Any])
        edit["splitScreen"] = nil
        let oldEdit = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: edit))
        #expect(oldEdit.splitScreen == SplitScreen())
    }

    @Test func aLayoutFromANewerVersionReadsAsTheStartingOne() throws {
        let json = #"{"layouts":[{"id":"6B7E4C1A-0D5B-4E8E-9B1F-2C3D4E5F6A7B","arrangement":"grid","ratio":"thirds","first":"third"}]}"#
        let read = try JSONDecoder().decode(SplitScreen.self, from: Data(json.utf8))
        let layout = try #require(read.layouts.first)
        #expect(layout.arrangement == .stacked)
        #expect(layout.ratio == .even)
        #expect(layout.first == .main)
    }

    @Test func theVideosLayoutKeepsItsIdentityAndEachRecordingItsFraming() {
        var split = SplitScreen()
        let first = SplitLayout()
        split.setLayout(first)
        var other = SplitLayout(arrangement: .sideBySide)
        other.id = UUID()
        split.setLayout(other)
        #expect(split.layouts.count == 1)
        #expect(split.layouts[0].id == first.id)
        #expect(split.layout(id: nil).arrangement == .sideBySide)
        let take2 = UUID()
        split.setFraming(AreaFraming(zoom: 2), for: nil)
        split.setFraming(AreaFraming(zoom: 3), for: take2)
        #expect(split.framing(for: nil).zoom == 2)
        #expect(split.framing(for: take2).zoom == 3)
        #expect(split.framing(for: UUID()) == AreaFraming())
    }
}
