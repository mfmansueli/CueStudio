//
//  DashRewriterTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// No dashes in anything the model writes, in any language: each one becomes the punctuation the sentence needs, nothing else changes, and a
/// draft shown as it arrives never takes a word back.
@Suite("DashRewriter")
struct DashRewriterTests {
    private static func language(_ code: String) -> Locale.Language { Locale.Language(identifier: code) }

    private func rewrite(_ text: String, _ code: String = "en", preserving: [String] = []) -> String {
        DashRewriter.rewrite(text, language: Self.language(code), preserving: preserving)
    }

    /// The range as the catalog writes it in that language (English until the catalog has it).
    private func range(_ lower: String, _ upper: String, _ code: String) -> String {
        String(format: DashRewriter.rangeTemplate(for: Self.language(code)), lower, upper)
    }

    // MARK: - Next to words

    @Test(arguments: [
        ("I believed this for years — until I checked.", "I believed this for years, until I checked."),
        ("Steal my system — it's simpler than you think.", "Steal my system. It's simpler than you think."),
        ("Number one — no phone.", "Number one: no phone."),
        ("Okay, real talk — this one matters.", "Okay, real talk: this one matters."),
        ("Three things matter — light, sound and a hook.", "Three things matter: light, sound and a hook."),
        ("Don't stop—now.", "Don't stop: now."),
        ("Don't stop – now.", "Don't stop: now."),
        ("My first video — the one nobody saw — still matters.", "My first video, the one nobody saw, still matters."),
        ("My setup — phone, light, mic — costs less than a lens.", "My setup (phone, light, mic) costs less than a lens."),
        ("I was about to say —", "I was about to say…"),
        ("Wait —!", "Wait!"),
        ("Ask me anything, — really.", "Ask me anything, really."),
        ("I tried everything - these are the ones that stuck.", "I tried everything. These are the ones that stuck."),
        ("The iPhone stays — iPhone users know why.", "The iPhone stays. iPhone users know why."),
    ])
    func aDashBecomesThePunctuationTheSentenceNeeds(text: String, expected: String) {
        #expect(rewrite(text) == expected)
    }

    @Test func frenchPutsANarrowSpaceBeforeTheColon() {
        #expect(rewrite("Regardez ça — c’est simple.", "fr") == "Regardez ça\u{202F}: c’est simple.")
    }

    @Test func germanStartsTheNewSentenceWithACapitalAndKnowsItsConnectors() {
        #expect(rewrite("Klau dir mein System – es ist einfacher, als du denkst.", "de") == "Klau dir mein System. Es ist einfacher, als du denkst.")
        #expect(rewrite("Und dann – bis ich nachsah.", "de") == "Und dann, bis ich nachsah.")
    }

    @Test func portugueseAndSpanishConnectorsTakeAComma() {
        #expect(rewrite("Acreditei nisso por anos — até conferir.", "pt") == "Acreditei nisso por anos, até conferir.")
        #expect(rewrite("Lo probé todo — y funcionó.", "es") == "Lo probé todo, y funcionó.")
    }

    @Test func turkishCapitalsFollowTurkish() {
        #expect(rewrite("Her şeyi denedim — işte kalıcı olanlar bunlar.", "tr") == "Her şeyi denedim. İşte kalıcı olanlar bunlar.")
    }

    // MARK: - Dialogue and lists

    @Test func aSpanishDialogueDashAndItsAsideBecomeCommas() {
        #expect(rewrite("—Hola —dijo Ana—. ¿Vienes?", "es") == "Hola, dijo Ana. ¿Vienes?")
    }

    @Test func aDialogueLineLosesItsMark() {
        #expect(rewrite("– Você vem?", "pt") == "Você vem?")
    }

    @Test func listMarksGoAndEachItemKeepsItsLine() {
        #expect(rewrite("Three habits:\n— No phone.\n— Water first.\n— Move.") == "Three habits:\nNo phone.\nWater first.\nMove.")
        #expect(rewrite("- No phone.\n- Water first.\n\n- Move.") == "No phone.\nWater first.\n\nMove.")
    }

    @Test func aDashAfterACueOrAFullStopIsAMarkToo() {
        #expect(rewrite("[pause] — and then we go.") == "[pause] and then we go.")
        #expect(rewrite("Done. — And then we go.") == "Done. And then we go.")
        #expect(rewrite("Okay — [pause] let's go.") == "Okay: [pause] let's go.")
    }

    // MARK: - Ranges

    @Test func rangesAreWrittenInWords() {
        #expect(rewrite("Try 3–5 tips a day.") == "Try 3 to 5 tips a day.")
        #expect(rewrite("Film from 9:00–10:30.") == "Film from 9:00 to 10:30.")
        #expect(rewrite("It ran 2024 – 2025.") == "It ran 2024 to 2025.")
        #expect(rewrite("Add 1,5–2 kg.") == "Add 1,5 to 2 kg.")
    }

    @Test(arguments: ["pt", "de", "fr", "tr", "ja", "ko", "zh-Hans", "ar", "th"])
    func rangesUseTheLanguagesOwnWord(code: String) {
        #expect(rewrite("3–5 x", code) == range("3", "5", code) + " x")
        #expect(rewrite("3—5 x", code) == range("3", "5", code) + " x")
    }

    @Test func theFullwidthHyphenIsAMinusBeforeANumberAndARangeBetweenTwo() {
        #expect(rewrite("気温は －5℃ でした。", "ja") == "気温は \u{2212}5℃ でした。")
        #expect(rewrite("3－5", "en") == "3 to 5")
    }

    // MARK: - Languages without spaces, and right to left

    @Test func chineseTakesItsFullwidthMarksWithoutSpaces() {
        #expect(rewrite("这个方法——真的很简单。", "zh-Hans") == "这个方法：真的很简单。")
        #expect(rewrite("我试了很多种办法 —— 但是只有一个有用。", "zh-Hans") == "我试了很多种办法，但是只有一个有用。")
    }

    @Test func japaneseUsesItsCommaAndAnEllipsisBeforeAClosingQuote() {
        #expect(rewrite("全部試した——残ったのはこれ。", "ja") == "全部試した、残ったのはこれ。")
        #expect(rewrite("「待って——」と言った。", "ja") == "「待って…」と言った。")
        #expect(rewrite("コーヒーを1〜3分。", "ja") == "コーヒーを1〜3分。")
    }

    @Test func arabicTakesItsOwnComma() {
        #expect(rewrite("جرّبت كل شيء — وهذا ما نجح.", "ar") == "جرّبت كل شيء، وهذا ما نجح.")
    }

    @Test func thaiSeparatesWithASpace() {
        #expect(rewrite("ลองมาหมดแล้ว — นี่คืออันที่ใช้ต่อ", "th") == "ลองมาหมดแล้ว นี่คืออันที่ใช้ต่อ")
    }

    @Test func hindiEndsTheSentenceWithADanda() {
        #expect(rewrite("मैंने सब आज़माया — ये टिके रहे।", "hi") == "मैंने सब आज़माया। ये टिके रहे।")
        #expect(!rewrite("मैंने सब आज़माया — ये टिके रहे।", "hi").contains("."))
    }

    // MARK: - What stays

    @Test(arguments: [
        "A follow-up e-mail, a T-shirt and Wi\u{2011}Fi at the co\u{2010}op.",
        "Turn it down \u{2212}3 dB.",
        "5 - 3 = 2, and -uiTestStubAI stays.",
        "Read https://example.com/a–b now.",
        "Follow @cue_studio and add #ad.",
        "コーヒー",
        "No dash here at all.",
    ])
    func whatIsNoDashIsLeftAsItIs(text: String) {
        #expect(rewrite(text) == text)
    }

    @Test func theCreatorsWordsKeepTheirDashes() {
        #expect(rewrite("Bora — gravando! Vamos lá — agora.", "pt", preserving: ["Bora — gravando!"]) == "Bora — gravando! Vamos lá: agora.")
        #expect(rewrite("Use code MORNING–20 today.", preserving: ["MORNING–20"]) == "Use code MORNING–20 today.")
        #expect(rewrite("Use code MORNING–20 today.") != "Use code MORNING–20 today.", "without it the code would be rewritten")
    }

    @Test func stageCuesStayWhereTheyAre() {
        #expect(rewrite("Okay — real talk. [pause] [look at camera] Three — no, four things.") == "Okay: real talk. [pause] [look at camera] Three: no, four things.")
    }

    // MARK: - Idempotence

    private static let samples = [
        "Okay, real talk — this one matters. Three things — light, sound and a hook.\n",
        "Steal my system — it's simpler than you think. Try 3–5 tips a day.\n",
        "My first video — the one nobody saw — still matters. I was about to say —\nThen I stopped.\n",
        "- No phone.\n- Water first.\n— Move.\n",
        "—Hola —dijo Ana—. ¿Vienes? Lo probé todo — y funcionó.\n",
        "[pause] — and then we go. Link: https://cue.studio/a–b today.\n",
        "I tried everything - these are the ones. 5 - 3 = 2.\n",
    ]

    @Test(arguments: samples)
    func rewritingTwiceChangesNothingMoreAndLeavesNoDash(sample: String) {
        let once = rewrite(sample)
        #expect(rewrite(once) == once)
        #expect(!DashRewriter.containsDash(once))
    }

    @Test func sentencesWithDashesAreTheCreatorsToKeep() {
        let text = "Not a to-do list — one thing. Then I move.\nNo dash — here? Yes."
        #expect(DashRewriter.sentencesWithDashes(in: text) == ["Not a to-do list — one thing.", "No dash — here?"])
    }

    // MARK: - Progressive generation

    private static let drafts: [(text: String, code: String)] = [
        (samples[0], "en"), (samples[1], "en"), (samples[2], "en"), (samples[3], "en"), (samples[4], "es"), (samples[5], "en"), (samples[6], "en"),
        ("这个方法——真的很简单。我试了很多种办法——但是只有一个有用。\n", "zh-Hans"),
        ("気温は －5℃ でした。「待って——」と言った。\n", "ja"),
        ("Klau dir mein System – es ist einfacher, als du denkst. Und dann – bis ich nachsah.\n", "de"),
        ("मैंने सब आज़माया — ये टिके रहे। फिर — मैंने छोड़ दिया।\n", "hi"),
        ("جرّبت كل شيء — وهذا ما نجح. ثم — توقفت.\n", "ar"),
        ("Regardez ça — c’est simple. Film 9:00–10:30, pas plus.\n", "fr"),
    ]

    /// Every snapshot of a draft, cut at every character, shows only the start of the finished text: no word is ever taken back.
    @Test(arguments: drafts.indices)
    func aDraftShownAsItArrivesNeverTakesAWordBack(index: Int) {
        let (text, code) = Self.drafts[index]
        let finished = rewrite(text, code)
        let characters = Array(text)
        for count in 0...characters.count {
            let shown = DashRewriter.displayable(String(characters.prefix(count)), language: Self.language(code))
            #expect(finished.hasPrefix(shown), "\(count): “\(shown)” is not the start of “\(finished)”")
            #expect(!DashRewriter.containsDash(shown))
        }
        #expect(DashRewriter.displayable(text, language: Self.language(code)) == finished, "a draft that ended is shown whole")
    }

    @Test(arguments: ["Steal my system —", "Steal my system — ", "Steal my system —i", "Steal my system - ", "Steal my system -"])
    func aSnapshotEndingAtADashShowsNothingFromTheDashOn(snapshot: String) {
        #expect(DashRewriter.displayable(snapshot, language: Self.language("en")) == "Steal my system")
    }

    @Test func aRangeStillArrivingShowsItsFirstNumber() {
        #expect(DashRewriter.displayable("Try 3–", language: Self.language("en")) == "Try 3")
        #expect(DashRewriter.displayable("Try 3–4", language: Self.language("en")) == "Try 3")
    }

    @Test func anUnfinishedCueOrLinkIsNotShown() {
        #expect(DashRewriter.displayable("Okay. [look at cam", language: Self.language("en")) == "Okay.")
        #expect(DashRewriter.displayable("Okay. Go to https://cue.stu", language: Self.language("en")) == "Okay. Go to")
    }

    @Test func aListMarkIsDroppedAsSoonAsItsWordsShow() {
        #expect(DashRewriter.displayable("- ", language: Self.language("en")).isEmpty)
        #expect(DashRewriter.displayable("- No ph", language: Self.language("en")) == "No ph")
        #expect(DashRewriter.displayable("—Ho", language: Self.language("es")) == "Ho")
    }
}
