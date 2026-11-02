//
//  VoiceInferenceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Cue noticed · right?" (the owner's item 6, 02/11/2026): what the creator did is offered to confirm, never used before they say yes.
@MainActor
struct VoiceInferenceTests {
    private func scripts(_ types: [ScriptType?]) -> [Script] {
        types.enumerated().map { index, type in
            Script(title: "S\(index)", text: "Text", platform: .tiktok, type: type, createdAt: Date(timeIntervalSince1970: Double(index) * 60))
        }
    }

    private func suggestions(
        _ profile: CreatorProfile = CreatorProfile(), scripts: [Script] = [], exports: [VoiceInference.Export] = [],
        gender: WordGender? = nil, asksGender: Bool = false
    ) -> [VoiceInference.Suggestion] {
        VoiceInference.suggestions(for: profile, scripts: scripts, exports: exports, deviceGender: gender, asksGender: asksGender)
    }

    @Test func whatTheyFilmMostIsOfferedWhenThreeOfTheLastSixAgree() {
        let mostlyTutorials = scripts([.story, .tutorial, nil, .tutorial, .list, .tutorial])
        #expect(suggestions(scripts: mostlyTutorials) == [.formats([.tutorial], scripts: 5)])
        #expect(suggestions(scripts: scripts([.story, .tutorial, .list, .tutorial])).isEmpty, "two of four: not enough")
        // The oldest ones don't count: only the last six.
        let old = scripts([.tutorial, .tutorial, .tutorial, .story, .list, .opinion, .review, .pov, .ad])
        #expect(suggestions(scripts: old).isEmpty)
        var answered = CreatorProfile()
        answered.formats = [.story]
        #expect(suggestions(answered, scripts: mostlyTutorials).isEmpty, "already answered")
    }

    @Test func whereTheyShareIsOfferedFromTwoExportsWithTheLength() {
        let exports: [VoiceInference.Export] = [
            .init(platform: .tiktok, seconds: 42), .init(platform: nil, seconds: 200), .init(platform: .tiktok, seconds: 55),
        ]
        #expect(suggestions(exports: exports) == [.reach(.tiktok, .thirtyToSixty, exports: 3)])
        #expect(suggestions(exports: [.init(platform: .reels, seconds: 20)]).isEmpty, "one export says little")
        var posting = CreatorProfile()
        posting.reach.platforms = [.shorts]
        #expect(suggestions(posting, exports: exports).isEmpty)
    }

    @Test func theTermOfAddressIsOfferedOnlyWhereTheLanguageNeedsIt() {
        #expect(suggestions(gender: .feminine, asksGender: true) == [.gender(.feminine)])
        #expect(suggestions(gender: .feminine, asksGender: false).isEmpty)
        var team = CreatorProfile()
        team.speaksAs = .we
        #expect(suggestions(team, gender: .feminine, asksGender: true).isEmpty, "a team isn't one person")
    }

    @Test func theEvidenceSaysWhereAnExportWent() {
        #expect(VoiceInference.platform(of: .tikTokShareKit) == .tiktok)
        #expect(VoiceInference.platform(of: .pasteboardHandoff) == .reels)
        #expect(VoiceInference.platform(of: .activity(type: "com.burbn.instagram.shareextension")) == .reels)
        #expect(VoiceInference.platform(of: .activity(type: "com.google.ios.youtube.shareextension")) == .shorts)
        #expect(VoiceInference.platform(of: .activity(type: "com.apple.UIKit.activity.Mail")) == nil)
        #expect(VoiceInference.platform(of: .photoLibrary(assetID: nil)) == nil)
    }

    @Test func yesMakesItTheAnswer() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.confirm(.formats([.tutorial], scripts: 5))
        service.confirm(.reach(.tiktok, .thirtyToSixty, exports: 3))
        service.confirm(.gender(.feminine))
        #expect(service.profile.formats == [.tutorial])
        #expect(service.profile.reach.platforms == [.tiktok] && service.profile.reach.length == .thirtyToSixty)
        #expect(service.profile.agreement.speaker == .feminine)
    }
}
