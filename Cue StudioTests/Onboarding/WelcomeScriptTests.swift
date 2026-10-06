//
//  WelcomeScriptTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The 1.1 opening (09 §12): the star lights five dots 0.2 s apart, lands on three words, returns to explode into the sixth dot, and the
/// rest arrives after it; everything is in place at the end.
@MainActor
@Suite("Welcome opening script")
struct WelcomeScriptTests {
    private let words = [CGPoint(x: 80, y: 665), CGPoint(x: 194, y: 665), CGPoint(x: 308, y: 665)]

    @Test func theStarLandsOnEachDotAtItsSecond() {
        let path = WelcomeScript.starPath(words: words)
        for dot in WelcomeScript.dots {
            let pose = path.pose(at: dot.hit)
            #expect(abs(pose.x - dot.point.x) < 0.01 && abs(pose.y - dot.point.y) < 0.01)
        }
        #expect(WelcomeScript.dots.map(\.hit) == [1.10, 1.30, 1.50, 1.70, 1.90])
    }

    @Test func theStarLandsOnTheWordsWhereTheyAre() {
        let path = WelcomeScript.starPath(words: words)
        for (index, hit) in WelcomeScript.wordHits.enumerated() {
            let pose = path.pose(at: hit)
            #expect(abs(pose.x - words[index].x) < 0.01 && abs(pose.y - words[index].y) < 0.01)
        }
        // On another screen the words are elsewhere, and the star follows.
        let moved = WelcomeScript.starPath(words: words.map { CGPoint(x: $0.x + 7, y: $0.y + 30) })
        #expect(abs(moved.pose(at: 3.55).x - 201) < 0.01)
    }

    @Test func theStarComesInFromTheTopRightAndIsGoneAfterTheExplosion() {
        let path = WelcomeScript.starPath(words: words)
        #expect(path.pose(at: 0).opacity == 0)
        #expect(path.pose(at: 0.55).x == 430 && path.pose(at: 0.55).y == -20)
        #expect(path.pose(at: 1.10).opacity == 1)
        let back = path.pose(at: 5.05)
        #expect(abs(back.x - WelcomeScript.cue.x) < 0.01 && abs(back.y - WelcomeScript.cue.y) < 0.01)
        #expect(path.pose(at: 5.17).opacity == 0)
        #expect(path.pose(at: WelcomeScript.finalTime).opacity == 0)
    }

    @Test func theLineAndTheLegDrawAsTheStarGoes() {
        #expect(WelcomeScript.line.pose(at: 1.0).scale == 0)
        #expect(abs(WelcomeScript.line.pose(at: 1.30).scale - 0.266) < 0.01)
        #expect(WelcomeScript.line.pose(at: 1.88).scale == 1)
        #expect(WelcomeScript.leg.pose(at: 1.9).scale == 0)
        #expect(WelcomeScript.leg.pose(at: 2.25).scale == 1)
    }

    @Test func theSixthDotStaysDimUntilTheExplosion() {
        #expect(abs(WelcomeScript.dimCue.pose(at: 3).opacity - 0.4) < 0.0001)
        #expect(WelcomeScript.dimCue.pose(at: 5.2).opacity == 0)
        #expect(WelcomeScript.core.pose(at: 4.9).scale == 0)
        #expect(WelcomeScript.core.pose(at: 5.15).scale > 2)
        #expect(WelcomeScript.core.pose(at: WelcomeScript.finalTime).scale == 1)
    }

    @Test func aDotPopsBigAtTheHitAndSettlesToOne() {
        let first = WelcomeScript.dots[0]
        #expect(first.pop.pose(at: first.hit - 0.1).opacity == 0)
        #expect(first.pop.pose(at: first.hit).scale == 2.0)
        #expect(first.pop.pose(at: first.hit + 0.35).scale == 1)
        let last = WelcomeScript.dots[4]
        #expect(last.pop.pose(at: last.hit).scale == 2.6)
    }

    @Test func theHapticsAreFiveSoftThreeLightAndOneSuccessInOrder() {
        let beats = WelcomeScript.beats
        #expect(beats.filter { $0.beat == .dot }.count == 5)
        #expect(beats.filter { $0.beat == .word }.count == 3)
        #expect(beats.filter { $0.beat == .explosion }.count == 1)
        #expect(beats.map(\.time) == beats.map(\.time).sorted())
        #expect(beats.last?.time == WelcomeScript.explosionTime)
    }

    @Test func aWordIsDimThenJumpsAndLightsAtTheHitThenSettles() {
        let pill = WelcomeScript.pill(hit: 2.95)
        #expect(abs(pill.pose(at: 2).opacity - 0.35) < 0.0001)
        let hit = pill.pose(at: 2.95)
        #expect(hit.y == -12 && hit.scale == 1.1 && hit.blur == 1)
        #expect(pill.pose(at: 6).blur == 0 && pill.pose(at: 6).y == 0 && pill.pose(at: 6).opacity == 1)
    }

    @Test func theWordmarkLettersGoOutwardAndAllSettle() {
        let letters = WelcomeScript.letters
        #expect(String(letters.map(\.character)) == "CUESTUDIO")
        #expect(letters.map(\.track).allSatisfy { $0.pose(at: WelcomeScript.finalTime).opacity == 1 })
        #expect(letters.map(\.track).allSatisfy { $0.pose(at: 5).opacity == 0 })
        // S and T leave first, C and O last.
        #expect(letters[3].track.pose(at: 5.3).opacity > letters[0].track.pose(at: 5.3).opacity)
        #expect(abs(WelcomeScript.tracking.pose(at: 5).scale - 1) < 0.0001)
        #expect(abs(WelcomeScript.tracking.pose(at: 7).scale - 0.34) < 0.0001)
    }

    @Test func everythingIsInPlaceAtTheEnd() {
        let end = WelcomeScript.finalTime
        for index in 0..<7 {
            let word = WelcomeScript.titleWord(index).pose(at: end)
            #expect(word.opacity == 1 && word.y == 0 && word.blur == 0)
        }
        #expect(WelcomeScript.subtitle.pose(at: end).opacity == 1)
        #expect(WelcomeScript.primaryButton.pose(at: end).opacity == 1)
        #expect(WelcomeScript.secondaryButton.pose(at: end).opacity == 1)
        #expect(WelcomeScript.halo.pose(at: end).opacity == 1)
        // The words of the title come 85 ms apart.
        let first = WelcomeScript.titleWord(0).keyframes[0].time
        #expect(abs(WelcomeScript.titleWord(1).keyframes[0].time - first - 0.085) < 0.0001)
    }

    @Test func theBurstsAreNineSparksAndTheExplosionTwelve() {
        #expect(WelcomeScript.dots.allSatisfy { $0.sparks.count == 9 })
        #expect(WelcomeScript.explosionSparks.count == 12)
        #expect(WelcomeScript.wordSparks.count == 3 && WelcomeScript.wordSparks.allSatisfy { $0.count == 7 })
        let spark = WelcomeScript.dots[0].sparks[0]
        #expect(spark.track.pose(at: 1.0).opacity == 0)
        #expect(spark.track.pose(at: 1.13).opacity == 1)
        #expect(spark.track.pose(at: 1.7).opacity == 0)
    }
}
