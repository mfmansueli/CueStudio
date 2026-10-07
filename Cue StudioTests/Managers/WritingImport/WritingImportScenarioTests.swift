//
//  WritingImportScenarioTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What a creator does with "Import my writing" in a day, the odd things included: other languages and scripts, a huge paste, a paste of links, a
/// creator who writes in two languages, an idea in another language than the writing, My Cue Voice turned off.
@MainActor
@Suite("Import my writing · a creator's day")
struct WritingImportScenarioTests {
    private func pieces(_ texts: [String]) -> [WritingPiece] {
        texts.map { WritingPiece(text: $0, source: "Pasted") }
    }

    private func service(importing texts: [String], role: CreatorRole? = .expert) -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile.role = role
        let analysis = WritingAnalyzer.analyze(pieces(texts))
        service.apply(WritingImportProposalBuilder.build(analysis: analysis, reading: nil, profile: service.profile))
        return (service, defaults)
    }

    private func factory(_ service: CreatorProfileService) -> ScriptRequestFactory {
        ScriptRequestFactory(
            rules: TestData.rulesService(), profile: service, scriptLanguage: nil, interfaceLanguage: .english, preferredLanguages: ["en-US"]
        )
    }

    // MARK: - Other languages and scripts

    private nonisolated static let languages: [(code: String, texts: [String])] = [
        ("ja", [
            "今日は朝のルーティンについて話します。まず水を一杯飲みます。次に五分だけストレッチをします。最後に今日いちばん大事なことを一つ書きます。これだけで一日が変わります。",
            "今日は夜のルーティンについて話します。まず部屋の明かりを少し落とします。次に五分だけ日記を書きます。最後に明日いちばん大事なことを一つ決めます。これだけで眠りが変わります。",
            "今日は勉強のルーティンについて話します。まず机の上を片づけます。次に二十五分だけ集中して取り組みます。最後に今日わかったことを一つ書きます。これだけで成績が変わります。",
            "今日は運動のルーティンについて話します。まず靴ひもをしっかり結びます。次に十分だけ歩きます。最後に今日の気分を一言で書きます。これだけで体が変わります。",
        ]),
        ("ko", [
            "오늘은 제 아침 루틴을 이야기해 볼게요. 먼저 물 한 잔을 마셔요. 그다음 오 분 동안 스트레칭을 해요. 마지막으로 오늘 가장 중요한 일을 하나 적어요. 해 보시고 어땠는지 알려 주세요.",
            "오늘은 제 저녁 루틴을 이야기해 볼게요. 먼저 조명을 조금 낮춰요. 그다음 오 분 동안 일기를 써요. 마지막으로 내일 가장 중요한 일을 하나 정해요. 해 보시고 어땠는지 알려 주세요.",
            "오늘은 제 공부 루틴을 이야기해 볼게요. 먼저 책상 위를 정리해요. 그다음 이십오 분 동안 집중해요. 마지막으로 오늘 배운 것을 하나 적어요. 해 보시고 어땠는지 알려 주세요.",
            "오늘은 제 운동 루틴을 이야기해 볼게요. 먼저 신발 끈을 단단히 묶어요. 그다음 십 분 동안 걸어요. 마지막으로 오늘 기분을 한 줄로 적어요. 해 보시고 어땠는지 알려 주세요.",
        ]),
        ("ar", [
            "اليوم سأخبركم عن روتيني الصباحي. أبدأ بشرب كوب من الماء. ثم أمارس التمدد لخمس دقائق. بعد ذلك أكتب أهم شيء لهذا اليوم. جربوا ذلك وأخبروني بالنتيجة.",
            "اليوم سأخبركم عن روتيني المسائي. أبدأ بتخفيف الإضاءة في الغرفة. ثم أكتب في مفكرتي لخمس دقائق. بعد ذلك أحدد أهم شيء لليوم التالي. جربوا ذلك وأخبروني بالنتيجة.",
            "اليوم سأخبركم عن روتين الدراسة عندي. أبدأ بترتيب المكتب. ثم أركز لخمس وعشرين دقيقة. بعد ذلك أكتب أهم شيء تعلمته اليوم. جربوا ذلك وأخبروني بالنتيجة.",
            "اليوم سأخبركم عن روتين الرياضة عندي. أبدأ بربط الحذاء جيدا. ثم أمشي لعشر دقائق. بعد ذلك أكتب شعوري في جملة واحدة. جربوا ذلك وأخبروني بالنتيجة.",
        ]),
        ("hi", [
            "आज मैं आपको अपनी सुबह की दिनचर्या बताऊँगा। सबसे पहले मैं एक गिलास पानी पीता हूँ। फिर पाँच मिनट स्ट्रेचिंग करता हूँ। उसके बाद आज का सबसे ज़रूरी काम लिखता हूँ। आप भी आज़माइए और मुझे बताइए।",
            "आज मैं आपको अपनी रात की दिनचर्या बताऊँगा। सबसे पहले मैं कमरे की रोशनी कम करता हूँ। फिर पाँच मिनट डायरी लिखता हूँ। उसके बाद कल का सबसे ज़रूरी काम तय करता हूँ। आप भी आज़माइए और मुझे बताइए।",
            "आज मैं आपको अपनी पढ़ाई की दिनचर्या बताऊँगा। सबसे पहले मैं मेज़ साफ़ करता हूँ। फिर पच्चीस मिनट ध्यान लगाकर पढ़ता हूँ। उसके बाद आज जो सीखा वह लिखता हूँ। आप भी आज़माइए और मुझे बताइए।",
            "आज मैं आपको अपनी कसरत की दिनचर्या बताऊँगा। सबसे पहले मैं जूते के फीते कसता हूँ। फिर दस मिनट टहलता हूँ। उसके बाद अपना मूड एक वाक्य में लिखता हूँ। आप भी आज़माइए और मुझे बताइए।",
        ]),
        ("th", [
            "วันนี้ผมจะเล่าเรื่องกิจวัตรตอนเช้า ผมเริ่มด้วยการดื่มน้ำหนึ่งแก้ว จากนั้นยืดเส้นห้านาที แล้วเขียนสิ่งสำคัญที่สุดของวันนี้ ลองทำดูแล้วบอกผมด้วยนะ",
            "วันนี้ผมจะเล่าเรื่องกิจวัตรตอนค่ำ ผมเริ่มด้วยการหรี่ไฟในห้อง จากนั้นเขียนไดอารี่ห้านาที แล้วเลือกสิ่งสำคัญที่สุดของพรุ่งนี้ ลองทำดูแล้วบอกผมด้วยนะ",
            "วันนี้ผมจะเล่าเรื่องกิจวัตรการเรียน ผมเริ่มด้วยการจัดโต๊ะให้เรียบร้อย จากนั้นจดจ่อยี่สิบห้านาที แล้วเขียนสิ่งที่ได้เรียนรู้วันนี้ ลองทำดูแล้วบอกผมด้วยนะ",
            "วันนี้ผมจะเล่าเรื่องกิจวัตรการออกกำลังกาย ผมเริ่มด้วยการผูกเชือกรองเท้าให้แน่น จากนั้นเดินสิบนาที แล้วเขียนความรู้สึกวันนี้หนึ่งประโยค ลองทำดูแล้วบอกผมด้วยนะ",
        ]),
    ]

    @Test(arguments: languages)
    func writingInAnotherLanguageIsReadWithoutAnythingBreaking(code: String, texts: [String]) {
        let analysis = WritingAnalyzer.analyze(pieces(texts))
        #expect(analysis.pieceCount == texts.count, "\(code): every text counts")
        #expect(analysis.language == code)
        #expect(analysis.fingerprint != nil)
        #expect(!analysis.excerpts.isEmpty && analysis.excerpts.allSatisfy { $0.language == code })
        #expect(analysis.excerpts.allSatisfy { $0.text.count <= VoiceExcerpt.maximumCharacters })
        if WritingLexicon.isUnspaced(code) { #expect(analysis.sentences == nil, "\(code): no sentence length from tokenized words") }
    }

    // MARK: - Odd pastes

    @Test func aHugePasteIsReadQuicklyAndCapped() {
        let raw = (1...300).map { n in
            "Script number \(n) is about topic \(n * 7) and what happened when I tried it for \(n) days in a row, which surprised me more than I expected."
                + " I wrote down every step, then I changed one thing at a time. Try it and tell me how it goes."
        }.joined(separator: "\n---\n")
        let started = ContinuousClock.now
        let found = WritingCleaner.pieces(from: raw)
        let analysis = WritingAnalyzer.analyze(found)
        let seconds = Double((ContinuousClock.now - started).components.seconds)
        #expect(found.count == WritingCleaner.maximumPieces)
        #expect(analysis.excerpts.count <= VoiceExcerpt.limit)
        #expect(seconds < 20, "reading a paste of the largest size takes seconds, not minutes")
    }

    @Test func aPasteOfLinksAndHashtagsIsNotAWriting() {
        let raw = "https://example.com/a #fitness #morning @someone https://example.com/b\n#one #two #three #four #five #six #seven #eight #nine #ten #eleven"
        #expect(WritingCleaner.pieces(from: raw).isEmpty)
    }

    @Test func captionsFullOfEmojiSoundLively() {
        let captions = (1...5).map { n in
            "Morning run done 🏃‍♀️🔥 and it felt amazing today, number \(n) of the month 💪 I am so proud of myself and so grateful 🙏 see you tomorrow ✨"
        }
        let distinct = captions.enumerated().map { $0.element.replacingOccurrences(of: "month", with: "month part \($0.offset)") }
        let analysis = WritingAnalyzer.analyze(pieces(distinct))
        #expect(analysis.fingerprint?.emojiPer100Words ?? 0 > 2)
        #expect(analysis.energy == .high)
    }

    @Test func aTextWithAPhoneNumberAndEmailKeepsNeitherInAnExcerpt() {
        let texts = WritingSamples.maya.map { $0 + " Call me at +1 555 123 4567 or write to maya@example.com." }
        let analysis = WritingAnalyzer.analyze(pieces(texts))
        #expect(!analysis.excerpts.isEmpty)
        #expect(analysis.excerpts.allSatisfy { !$0.text.contains("555") && !$0.text.contains("@") })
    }

    // MARK: - Using it

    @Test func theRequestCarriesTheWritingOnlyForScriptsInItsLanguage() {
        let (service, defaults) = service(importing: WritingSamples.maya)
        defer { defaults.tearDown() }
        let english = factory(service).request(idea: "Three morning habits that changed my energy", platform: .tiktok, format: nil)
        #expect(english.voice?.excerpts.count == 2 && english.voice?.fingerprint != nil)
        let portuguese = factory(service).request(idea: "Três hábitos de manhã que mudaram a minha energia", platform: .tiktok, format: nil)
        #expect(portuguese.voice != nil && portuguese.voice?.excerpts.isEmpty == true && portuguese.voice?.fingerprint == nil)
    }

    @Test func theBriefWithImportedWritingStillFitsAndSaysWhatWasMeasured() throws {
        let (service, defaults) = service(importing: WritingSamples.daniel)
        defer { defaults.tearDown() }
        let request = factory(service).request(idea: "How to start investing with little money", platform: .tiktok, format: nil)
        let voice = try #require(request.voice)
        let brief = VoiceBriefBuilder.brief(for: voice)
        #expect(brief.length <= VoiceBrief.budget)
        #expect(brief.text.contains("Here is how they write"))
        #expect(brief.text.contains("They almost never use exclamation marks."))
        #expect(ScriptPromptBuilder.instructions(for: request).contains("Here is how they write"))
    }

    @Test func aCreatorWhoTurnsMyVoiceOffSendsNothingOfWhatTheyImported() {
        let (service, defaults) = service(importing: WritingSamples.maya)
        defer { defaults.tearDown() }
        service.profile.usesVoiceInAI = false
        let request = factory(service).request(idea: "Three morning habits that changed my energy", platform: .tiktok, format: nil)
        #expect(request.voice == nil)
        #expect(!ScriptPromptBuilder.instructions(for: request).contains("Okay, real talk"))
    }

    @Test func aSeriousFormatSendsNothingOfIt() {
        let (service, defaults) = service(importing: WritingSamples.maya)
        defer { defaults.tearDown() }
        let seriousFormat = ScriptType.allCases.first { $0.structure.isSerious }
        guard let seriousFormat else { return }
        let request = factory(service).request(idea: "A public apology to my followers", platform: .tiktok, format: seriousFormat)
        #expect(request.voice == nil)
    }

    @Test func aCreatorWhoWritesInTwoLanguagesGetsEachOnesOwnExcerpts() {
        let (service, defaults) = service(importing: WritingSamples.maya + WritingSamples.rafa)
        defer { defaults.tearDown() }
        let kept = service.profile.excerpts
        #expect(kept.contains { $0.language == "en" })
        #expect(!kept.contains { $0.language == "pt" }, "only the main language of an import is read, so the Portuguese needs its own import")
    }
}
