import Foundation
import Testing
@testable import Cue_Studio

extension ScriptQualityDeviceTests {
    /// Read the saved profile, clone it into test defaults and retain only outputs locally.
    /// Never use the public quality collector for these attachments: they may reflect personal context.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_SAVED_CREATOR_COMPARISON"] == "1"))
    func comparesUsingTheSavedCreatorProfile() async throws {
        guard UserDefaults.standard.object(forKey: DefaultsKey.onDeviceAI) as? Bool != false else {
            try Test.cancel("Apple Intelligence is disabled in the saved preferences")
        }
        let saved = CreatorProfileService()
        guard saved.writesInMyVoice else {
            try Test.cancel("No enabled saved My Cue Voice profile; do not substitute a synthetic profile")
        }
        let service = ScriptAIService(preferredModel: .privateCloud)
        guard service.availability.privateCloud else { try Test.cancel("PCC unavailable; comparison not validated") }
        KeepScreenAwake.enable()
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let clone = CreatorProfileService(defaults: defaults.defaults)
        clone.profile = saved.profile
        let wanted = ["pt-BR-tutorial", "pt-BR-editorial-draft", "en-US-comparison"]
        let cases = try ScriptIntentCase.load()
        var outputs: [[String: String]] = []
        for id in wanted {
            let item = try #require(cases.first { $0.id == id })
            let factory = ScriptRequestFactory(
                profile: clone, scriptLanguage: item.language, interfaceLanguage: item.language
            )
            let request = factory.request(idea: item.prompt, platform: .reels, format: nil)
            let script = try await service.generate(request)
            #expect(script.model == .privateCloud, "The actual route must be PCC")
            outputs.append([
                "caseID": id, "prompt": item.prompt, "text": script.text,
                "model": script.model?.rawValue ?? "unknown", "profile": "saved creator preferences; raw writing samples excluded by normal policy",
                "needsFactCheck": String(script.needsFactCheck), "quality": "Requires editorial review; not a semantic pass",
            ])
        }
        Attachment.record(try JSONEncoder().encode(outputs), named: "private-saved-creator-comparison.json")
        #expect(outputs.count == wanted.count)
    }
}
