//
//  SponsoredAdWordingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A sponsored ad says it is paid and keeps what the brand gave word for word (`SponsoredDisclosure`, `VoiceCheckedWriting.brandWording`):
/// Private Cloud Compute left the disclosure out of 6 ads in 8, the device's model the brand's line out of 4 (the Ultra study on Apple
/// Intelligence, 04/11/2026).
@MainActor
struct SponsoredAdWordingTests {
    /// The scripts a fake model writes, in order, and the violations each attempt was told.
    @MainActor
    private final class Model {
        var outputs: [String]
        private(set) var told: [[VoiceViolation]] = []

        init(_ outputs: [String]) { self.outputs = outputs }

        var writing: VoiceCheckedWriting {
            VoiceCheckedWriting(
                draft: { [self] _, violations in
                    told.append(violations)
                    return GeneratedScript(title: "T", text: outputs.removeFirst(), usedLanguageModel: true)
                },
                isGuardrailRefusal: { _ in false },
                report: { _, _ in }
            )
        }
    }

    private static let brand = BrandBrief(
        name: "SkipRight", product: "weighted jump rope", mustSay: "The cable adjusts to your height in seconds", link: "skipright.com",
        code: "CUE15"
    )

    private static let body = "My cardio at home got faster once the rope fit me. If the length is wrong you catch your feet and lose the "
        + "rhythm, so you stop and reset every few jumps. The cable adjusts to your height in seconds, so I set it once and keep moving. "
        + "Pull it until the handles reach your armpits, then lock it and start slow. Get it at skipright.com with the code CUE15."

    private func ad(_ brand: BrandBrief? = Self.brand) -> ScriptRequest {
        var request = ScriptRequest(source: .prompt("The jump rope I use for quick cardio"), platform: .tiktok, voice: nil, targetRange: 30...60)
        request.brand = brand
        request.durationPolicy = .informative
        return request
    }

    // MARK: - The disclosure, in Cue's languages

    @Test(arguments: [
        "This video is a paid partnership with SkipRight.", "#ad Here is the rope I use.", "Isso é publi da Gestor Claro.",
        "Trata-se de uma parceria paga com a Gestor Claro.", "Este video está patrocinado por SkipRight.", "Dieses Video ist Werbung.",
        "Ce contenu est un partenariat rémunéré.", "Questo video è una collaborazione retribuita.", "Dit is een betaalde samenwerking.",
        "Det här är ett betalt samarbete.", "Dette er et betalt samarbejde.", "Dette er et betalt samarbeid.", "Bu video sponsorlu.",
        "Video ini kerja sama berbayar.", "Đây là video quảng cáo.", "この動画はプロモーションを含みます。", "이 영상은 유료 광고를 포함합니다.",
        "本视频包含广告。", "本影片為業配。", "यह वीडियो प्रायोजित है।", "هذا الفيديو برعاية SkipRight.", "วิดีโอนี้เป็นโฆษณา",
        "This is an ad for a rope I like.",
    ])
    func aDisclosureIsHeardInEveryLanguage(_ text: String) {
        #expect(SponsoredDisclosure.isSaid(in: text))
    }

    @Test(arguments: [
        "The rope I use for quick cardio at home.", "#adoro essa corda e o público também.", "Fiz um prato com amigos.", "I had to add more reps.",
        "[pause] Advanced moves come later.",
    ])
    func wordsThatOnlyLookLikeOneAreNot(_ text: String) {
        #expect(!SponsoredDisclosure.isSaid(in: text))
    }

    // MARK: - What is written once more

    @Test func anAdWithoutItsDisclosureIsWrittenOnceMoreToldToSayIt() async throws {
        let model = Model([Self.body, Self.body + " This video is a paid partnership with SkipRight."])
        let script = try await model.writing.write(ad())
        #expect(model.told.count == 2)
        #expect(model.told[1].map(\.kind) == [.brandWording])
        #expect(model.told[1][0].detail.contains("paid partnership with SkipRight"))
        #expect(script.attempts == 2 && script.text.contains("paid partnership"))
    }

    @Test func eachMissingWordOfTheBrandIsToldAsGiven() async throws {
        let model = Model(["#ad This rope is great for cardio at home, and it fits anyone who jumps.", Self.body + " #ad"])
        _ = try await model.writing.write(ad())
        let details = model.told[1].filter { $0.kind == .brandWording }.map(\.detail)
        #expect(details.count == 3)
        #expect(details.contains { $0.contains("“The cable adjusts to your height in seconds”") })
        #expect(details.contains { $0.contains("“skipright.com”") } && details.contains { $0.contains("“CUE15”") })
    }

    @Test func anAdThatSaysItAllIsWrittenOnceAndTheCaseOfTheLinkDoesNotCount() async throws {
        let said = Self.body.replacingOccurrences(of: "skipright.com", with: "SkipRight.com") + " It's a paid partnership."
        let model = Model([said])
        let script = try await model.writing.write(ad())
        #expect(model.told.count == 1 && script.voiceViolations.isEmpty)
    }

    @Test func aScriptThatIsNoAdIsNeverAskedForADisclosure() async throws {
        let model = Model([Self.body])
        let script = try await model.writing.write(ad(nil))
        #expect(model.told.count == 1 && script.voiceViolations.isEmpty)
    }
}
