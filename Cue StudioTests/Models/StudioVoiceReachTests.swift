//
//  StudioVoiceReachTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Which recordings Studio Voice treats in a montage, how each is treated, and how much evening out raises or lowers them.
@Suite("Studio Voice over a montage")
struct StudioVoiceReachTests {
    private let video = UUID()
    private let other = UUID()

    private func montage() -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        for (id, title) in [(video, "Video"), (other, "Take 2")] {
            var source = ClipSource(fileName: "\(id).mov", duration: 5, title: title)
            source.id = id
            edit.sources.append(source)
            edit.timeline.insertClip(source: id, duration: 5)
        }
        return edit
    }

    @Test func newEditsTreatEveryRecordingButTheOnesLeftOut() {
        var edit = montage()
        edit.noiseReduction = .strong
        #expect(edit.treatedRecordingIDs == [nil, video, other])
        #expect(edit.voiceProcessing(for: video).noise == .strong)
        #expect(edit.voiceProcessing(for: video).isNeeded)
        edit.voiceReach = edit.voiceReach.setting(video, treated: false, among: [video, other])
        #expect(edit.treatedRecordingIDs == [nil, other])
        #expect(!edit.voiceProcessing(for: video).isNeeded)
        #expect(edit.evensOutLevels)
    }

    @Test func theTakesVolumeStaysWithTheTake() {
        var edit = montage()
        edit.volume = 1.4
        #expect(edit.voiceProcessing(for: nil).volume == 1.4)
        #expect(edit.voiceProcessing(for: other).volume == 1)
    }

    @Test func editsSavedBeforeTreatOnlyTheTakeAndDontEvenOut() throws {
        var edit = montage()
        edit.voiceEnhancement = .strong
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(edit)) as? [String: Any])
        json["voiceReach"] = nil
        json["evensOutVoices"] = nil
        let old = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.voiceReach == .takeOnly)
        #expect(old.treatedRecordingIDs == [nil])
        #expect(!old.voiceProcessing(for: video).isNeeded)
        #expect(!old.evensOutLevels)
        // Treating one of them makes the rest explicit: the others stay as they were.
        let reach = old.voiceReach.setting(video, treated: true, among: [video, other])
        #expect(reach.treats(video) && !reach.treats(other))
    }

    @Test func aTakeAloneHasNothingToEvenOut() {
        let edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        #expect(!edit.evensOutLevels)
    }

    @Test func undoTakesTheReachBack() {
        var edit = montage()
        let before = EditLook(edit)
        edit.voiceReach = .allRecordings(except: [other])
        edit.evensOutVoices = false
        before.apply(to: &edit)
        #expect(edit.voiceReach == .standard)
        #expect(edit.evensOutVoices)
    }

    // MARK: - Evening out

    @Test func quieterAndLouderClipsMeetTheTake() {
        let gains = VoiceLeveling.gains(levels: [nil: -20, video: -26, other: -17.5])
        #expect(gains[nil] == nil)
        #expect(gains[video] == 6)
        #expect(gains[other] == -2.5)
    }

    @Test func theGainHasLimitsAndSmallDifferencesStay() {
        let gains = VoiceLeveling.gains(levels: [nil: -18, video: -40, other: -18.6])
        #expect(gains[video] == VoiceLeveling.maximumBoost)
        #expect(gains[other] == nil)
        #expect(VoiceLeveling.gains(levels: [nil: -40, video: -10])[video] == VoiceLeveling.maximumCut)
    }

    @Test func withoutSpeechInTheTakeTheLoudestLeads() {
        let gains = VoiceLeveling.gains(levels: [video: -24, other: -18])
        #expect(gains[video] == 6)
        #expect(gains[other] == nil)
        #expect(VoiceLeveling.gains(levels: [nil: -20]).isEmpty)
    }
}
