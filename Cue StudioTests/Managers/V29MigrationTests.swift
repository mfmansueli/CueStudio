//
//  V29MigrationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What v27 saved must open in v29 with the same visible values (05 · Data migration): scripts.json with no
/// `isFinished`, an `ad` script with the old brief, a profile with none of the new fields and prompter settings
/// with no box or reading line of their own.
@MainActor
@Suite("v27 → v29 migration")
struct V29MigrationTests {
    // swiftlint:disable line_length
    /// A library as v27 wrote it: no `isFinished` anywhere, an `ad` script, an empty script, a script of a format
    /// this build doesn't know (a newer build wrote it).
    private let v27Library = """
    {"folders":["Brand deals"],"scripts":[
      {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Oat & Co. — sponsored","text":"Okay, I have to tell you about Oat & Co. [pause]\\n\\nThis fixes it.",
       "platform":"tiktok","type":"ad","version":2,"folder":"Brand deals","createdAt":"2026-09-01T10:00:00Z","updatedAt":"2026-09-02T10:00:00Z","topic":"money"},
      {"id":"6F9619FF-8B86-D011-B42D-00C04FC964A1","title":"","text":"   \\n ","platform":"reels",
       "createdAt":"2026-09-03T10:00:00Z","updatedAt":"2026-09-03T10:00:00Z"},
      {"id":"6F9619FF-8B86-D011-B42D-00C04FC964A2","title":"From the future","text":"Hello there.","platform":"shorts","type":"holographic",
       "version":1,"createdAt":"2026-09-04T10:00:00Z","updatedAt":"2026-09-04T10:00:00Z"}
    ]}
    """
    // swiftlint:enable line_length

    private func decodedLibrary() throws -> ScriptLibrarySnapshot {
        try JSONDecoder.library.decode(ScriptLibrarySnapshot.self, from: Data(v27Library.utf8))
    }

    // MARK: - Scripts

    @Test func aScriptWithTextIsFinishedAndAnEmptyOneIsADraft() throws {
        let scripts = try decodedLibrary().scripts
        #expect(scripts[0].isFinished)
        #expect(!scripts[1].isFinished)
        #expect(scripts[2].isFinished)
    }

    @Test func noScriptChangesItsTextIdVersionOrTitle() throws {
        let scripts = try decodedLibrary().scripts
        #expect(scripts.map(\.title) == ["Oat & Co. — sponsored", "", "From the future"])
        #expect(scripts[0].text.hasPrefix("Okay, I have to tell you about Oat & Co."))
        #expect(scripts[0].version == 2)
        #expect(scripts[0].id == UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF"))
        #expect(scripts[0].type == .ad)
        #expect(scripts[0].topic == "money")
        #expect(scripts[0].folder == "Brand deals")
    }

    @Test func aFormatFromANewerBuildReadsAsNoFormatAndTheLibraryStillOpens() throws {
        let snapshot = try decodedLibrary()
        #expect(snapshot.scripts.count == 3)
        #expect(snapshot.scripts[2].type == nil)
        #expect(snapshot.scripts[2].text == "Hello there.")
    }

    @Test func theLibraryLoadsFromDiskAndKeepsItsScriptsAfterBeingSavedAgain() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "cue-migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(v27Library.utf8).write(to: directory.appending(path: "scripts.json"))

        let service = ScriptLibraryService(repository: LocalScriptRepository(directory: directory))
        service.load()
        #expect(service.scripts.count == 3)
        service.setFinished(true, of: UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964A1") ?? UUID())

        let reloaded = ScriptLibraryService(repository: LocalScriptRepository(directory: directory))
        reloaded.load()
        let empty = reloaded.scripts.first { $0.title.isEmpty }
        #expect(empty?.isFinished == true)
        #expect(reloaded.scripts.count == 3)
    }

    @Test func isFinishedIsWrittenSoItIsNotGuessedAgain() throws {
        var script = Script(title: "A", text: "Words", platform: .tiktok)
        script.isFinished = false
        let decoded = try JSONDecoder.library.decode(Script.self, from: JSONEncoder.library.encode(script))
        #expect(!decoded.isFinished)
    }

    // MARK: - Ad brief

    @Test func anOldAdBriefBecomesABrandOnce() {
        let store = BrandStore(repository: InMemoryBrandRepository())
        let legacy = [
            "brand": "Oat & Co. barista oat milk", "pain": "Oat milk that never foams",
            "benefit": "Foams like dairy, zero aftertaste", "proof": "A latte-art pour", "offer": "Code MORNING for 20% off",
        ]
        let first = store.adopt(legacyAdBrief: legacy)
        let second = store.adopt(legacyAdBrief: legacy)
        #expect(store.brands.count == 1)
        #expect(first?.id == second?.id)
        #expect(first?.name == "Oat & Co. barista oat milk")
        #expect(first?.mustSay == "Foams like dairy, zero aftertaste")
        #expect(first?.code == "Code MORNING for 20% off")
        #expect(first?.isUsable == true)
    }

    @Test func anOldAdBriefWithALinkKeepsItAsTheLink() {
        let brief = BrandBrief(legacyAdBrief: ["brand": "Oat & Co.", "offer": "oatandco.com/maya"])
        #expect(brief.link == "oatandco.com/maya")
        #expect(brief.code.isEmpty)
        #expect(brief.product == "Oat & Co.")
    }

    @Test func anOldAdBriefWithNoBrandAddsNothing() {
        let store = BrandStore(repository: InMemoryBrandRepository())
        #expect(store.adopt(legacyAdBrief: ["pain": "x"]) == nil)
        #expect(store.brands.isEmpty)
    }

    // MARK: - Profile

    private let v27Profile = """
    {"name":"Maya Reyes","handle":"mayamakes","niches":["wellness","tech"],"customTopics":["Slow mornings"],
     "phrases":["Hey fam"],"role":"personal","voiceApproved":true,"sounds":["casual","funny"],"vocabulary":"genZ",
     "styles":["shortSentences"],"usesVoiceInAI":true,"defaultPlatform":"reels","monetizationGoals":false,
     "confirmedVoiceSteps":["audience","tone"],"unverifiedVoiceSteps":[]}
    """

    @Test func aV27ProfileKeepsEveryValueAndGetsEmptyNewFields() throws {
        let profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(v27Profile.utf8))
        #expect(profile.name == "Maya Reyes")
        #expect(profile.handle == "mayamakes")
        #expect(profile.niches == [.wellness, .tech])
        #expect(profile.customTopics == ["Slow mornings"])
        #expect(profile.phrases == ["Hey fam"])
        #expect(profile.role == .personal)
        #expect(profile.sounds == [.casual, .funny])
        #expect(profile.vocabulary == .genZ)
        #expect(profile.defaultPlatform == .reels)
        #expect(profile.openings.isEmpty && profile.endings.isEmpty && profile.formats.isEmpty)
        #expect(profile.swearing == nil)
        #expect(profile.examples.isEmpty && profile.customTags.isEmpty)
        #expect(profile.hasMinimumVoice)
    }

    @Test func aV27ProfileRoundTripsWithTheNewFieldsAbsentOrEmpty() throws {
        let profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(v27Profile.utf8))
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded == profile)
    }

    // MARK: - Prompter settings

    @Test func v27PrompterSettingsKeepTheBoxAndTheReadingLine() throws {
        let v27 = """
        {"speed":0.6976744186,"speedCalibration":215,"font":"lexend","size":36,"margin":20,"readingWidth":0.75,
         "textWindowHeight":300,"readingLineOffset":40,"scrollMode":"voice"}
        """
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(v27.utf8))
        #expect(settings.boxWidth == 0.75)
        #expect(settings.boxHeight == 300)
        #expect(settings.readingLineOffset == 40)
        #expect(settings.scrollMode == .voice)
    }

    @Test func settingsWithNoBoxAtAllOpenAtTodaysSizeAndTheRecommendedLine() throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"size":30}"#.utf8))
        #expect(settings.boxWidth == 0.93)
        #expect(settings.boxHeight == 380)
        #expect(settings.readingLineOffset == nil)
        // "Absent" keeps the line where it is today (118 pt under the lens), whatever percent that is on this screen.
        #expect(settings.readingLine(on: .standard) == ReadingLinePercent.standard.percent(for: ReadingLinePlacement(offset: nil)) / 100)
    }
}
