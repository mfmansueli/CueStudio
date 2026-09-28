//
//  PrompterScrollEngineTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("PrompterScrollEngine")
struct PrompterScrollEngineTests {
    private func makeEngine() -> PrompterScrollEngine {
        var engine = PrompterScrollEngine()
        engine.updateLayout(contentHeight: 1000, lineHeight: 40, wordCount: 100)
        return engine
    }

    @Test func endsWhenTheLastLineReachesTheGuide() {
        #expect(makeEngine().endOffset == 960)
    }

    @Test func oneXReads215WordsPerMinute() {
        // 10 points per word.
        #expect(abs(makeEngine().pointsPerSecond(speed: 1) - 215.0 / 60 * 10) < 0.0001)
    }

    @Test func theDefaultSpeedReadsAbout150WordsPerMinute() {
        // 2.5 words per second over 10 points per word.
        #expect(abs(makeEngine().pointsPerSecond(speed: ReadTime.naturalSpeed) - 25) < 0.1)
    }

    @Test func advanceMovesBySpeedAndTime() {
        var engine = makeEngine()
        engine.advance(by: 2, speed: 1)
        #expect(abs(engine.offset - 2 * 215.0 / 60 * 10) < 0.0001)
    }

    @Test func advanceReportsTheEndOnce() {
        var engine = makeEngine()
        let reachedEnd = engine.advance(by: 100, speed: 1)
        let reachedAgain = engine.advance(by: 1, speed: 1)
        #expect(reachedEnd)
        #expect(engine.isAtEnd)
        #expect(!reachedAgain)
    }

    @Test func scrollingIsClamped() {
        var engine = makeEngine()
        engine.scroll(by: -100)
        #expect(engine.offset == 0)
        engine.scroll(by: 5000)
        #expect(engine.offset == 960)
    }

    @Test func jumpMovesWholeLines() {
        var engine = makeEngine()
        engine.jump(lines: 3)
        #expect(engine.offset == 120)
    }

    @Test func shorterLayoutClampsTheOffset() {
        var engine = makeEngine()
        engine.scroll(by: 900)
        engine.updateLayout(contentHeight: 500, lineHeight: 40, wordCount: 100)
        #expect(engine.offset == 460)
    }

    @Test func glideEasesTowardTheTarget() {
        var engine = makeEngine()
        engine.glide(toward: 100, by: PrompterScrollEngine.glideTime)
        // About two thirds of the way in one glide time.
        #expect(engine.offset > 60 && engine.offset < 67)
        for _ in 0..<200 { engine.glide(toward: 100, by: 1.0 / 60) }
        #expect(engine.offset == 100)
    }

    @Test func glideNeverMovesBack() {
        var engine = makeEngine()
        engine.scroll(by: 200)
        let moved = engine.glide(toward: 100, by: 1)
        #expect(!moved)
        #expect(engine.offset == 200)
    }

    @Test func glideReportsTheEndOnce() {
        var engine = makeEngine()
        var ends = 0
        for _ in 0..<600 where engine.glide(toward: 5000, by: 1.0 / 60) { ends += 1 }
        #expect(ends == 1)
        #expect(engine.offset == 960)
    }

    @Test func emptyScriptDoesNotScroll() {
        var engine = PrompterScrollEngine()
        let moved = engine.advance(by: 1, speed: 1)
        #expect(engine.pointsPerSecond(speed: 1) == 0)
        #expect(!moved)
    }
}
