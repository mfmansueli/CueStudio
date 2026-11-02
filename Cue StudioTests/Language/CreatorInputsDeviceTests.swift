//
//  CreatorInputsDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// The baseline of the creator-inputs audit (`reports/entradas-do-criador-2026-11-01-completo.md`, plan stage 0): what the real models write today
/// for creators whose language marks the speaker's gender (women writing in Portuguese, Spanish, Italian and French, with nothing in the profile that
/// says so, as the app has no such field), and for creators who chose an ending, an opening and a catchphrase. Each case is written on the route the
/// app takes (Private Cloud Compute first) and on the iPhone's own model. The scripts are kept as attachments and printed on one line each
/// (`CREATOR_INPUTS_SAMPLE {json}`); scoring is done outside the app. Also records what iOS says of the person's Term of Address.
///
/// Opt-in and on a device with Apple Intelligence on, unlocked and awake:
/// `TEST_RUNNER_CUE_AI_E2E=1 CUE_DEVICE=<iPhone> scripts/test.sh device CreatorInputsDeviceTests`.
@MainActor
@Suite("Creator inputs baseline", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct CreatorInputsDeviceTests {
    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let id: String
        let preferredLanguage: String
        let profile: CreatorProfile
        let ideas: [String]
        var testDescription: String { id }
    }

    nonisolated struct Sample: Codable, Sendable {
        let caseID: String
        let route: String
        let model: String?
        let ideaIndex: Int
        let idea: String
        let title: String?
        let text: String?
        let failure: String?
        let seconds: Double
        /// Whether the page would ask the creator to check the facts (`ScriptFactCheckPolicy`): the run of 01/11 didn't record it, so "Eu perdi
        /// 2 quilos em 7 dias" could only be judged from the code (§11, A11a).
        var needsFactCheck: Bool?
    }

    nonisolated enum Route: String, Sendable, CaseIterable {
        /// The app's own choice: Private Cloud Compute first for a script.
        case app
        /// The iPhone's model only.
        case device
        /// Private Cloud Compute asked for first (the run is cancelled when it isn't available).
        case cloud
    }

    nonisolated struct Argument: Sendable, CustomTestStringConvertible {
        let item: Case
        let route: Route
        var testDescription: String { "\(item.id)·\(route.rawValue)" }
    }

    nonisolated static let cases: [Case] = [
        Case(
            id: "pt-fitness-woman", preferredLanguage: "pt-BR",
            profile: profile(role: .expert, niches: [.fitness], sounds: [.energetic, .confident]),
            ideas: [
                "Como eu me senti no meu primeiro mês treinando em casa",
                "O dia em que eu desisti da dieta e o que aprendi com isso",
                "Por que eu parei de treinar todo dia e fiquei mais forte",
            ]
        ),
        Case(
            id: "es-beauty-woman", preferredLanguage: "es-ES",
            profile: profile(role: .personal, niches: [.beauty], sounds: [.casual, .warmCalm]),
            ideas: [
                "Lo que aprendí cuando dejé de maquillarme durante un mes",
                "Mi primera vez probando una rutina coreana de skincare",
                "Por qué casi abandono mi rutina de noche y qué me hizo volver",
            ]
        ),
        Case(
            id: "it-food-woman", preferredLanguage: "it-IT",
            profile: profile(role: .personal, niches: [.food], sounds: [.casual, .funny]),
            ideas: [
                "La prima volta che ho cucinato per venti persone",
                "Cosa ho imparato quando ho smesso di comprare cibo pronto",
                "Il giorno in cui ho bruciato la cena davanti ai miei suoceri",
            ]
        ),
        Case(
            id: "fr-travel-woman", preferredLanguage: "fr-FR",
            profile: profile(role: .personal, niches: [.travel], sounds: [.casual, .confident]),
            ideas: [
                "Mon premier voyage en sac à dos et ce que j'en ai retenu",
                "Le jour où j'ai raté mon avion à l'autre bout du monde",
                "Pourquoi j'ai arrêté de tout planifier en voyage",
            ]
        ),
        Case(
            id: "en-no-cta", preferredLanguage: "en-US",
            profile: profile(
                role: .educator, niches: [.productivity], sounds: [.educational, .confident],
                phrases: ["Here's the thing"], openings: ["Question"], endings: ["No call to action"]
            ),
            ideas: [
                "Why to-do lists make you less productive",
                "The one habit that fixed my mornings",
                "How to stop checking your phone at work",
            ]
        ),
        Case(
            id: "pt-follow-cta", preferredLanguage: "pt-BR",
            profile: profile(
                role: .personal, niches: [.lifestyle], sounds: [.casual, .energetic],
                phrases: ["Bora lá"], openings: ["Question"], endings: ["Follow for more"]
            ),
            ideas: [
                "Três coisas que mudaram a minha rotina de manhã",
                "Como eu organizo a semana no domingo à noite",
                "O erro que eu cometia toda vez que tentava acordar cedo",
            ]
        ),
    ]

    nonisolated static let arguments: [Argument] = {
        let routes: [Route] = {
            guard let named = ProcessInfo.processInfo.environment["CUE_INPUTS_ROUTES"], !named.isEmpty else { return Route.allCases }
            return named.split(separator: ",").compactMap { Route(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
        }()
        let all = cases.flatMap { item in routes.map { Argument(item: item, route: $0) } }
        guard let named = ProcessInfo.processInfo.environment["CUE_INPUTS_CASES"], !named.isEmpty else { return all }
        let wanted = Set(named.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return all.filter { wanted.contains($0.item.id) || wanted.contains($0.testDescription) }
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    // MARK: - Term of Address

    @Test func recordsTheTermOfAddress() throws {
        let user = __NSMorphology.user
        let gender = (user as Morphology).grammaticalGender.map { "\($0)" } ?? "nil"
        let availability = ScriptAIService().availability
        let line = "unspecified=\(user.isUnspecified) gender=\(gender) languages=\(Locale.preferredLanguages.prefix(3).joined(separator: ","))"
            + " onDevice=\(availability.onDevice) privateCloud=\(availability.privateCloud) reason=\(availability.reason ?? "none")"
        print("CREATOR_INPUTS_TERM_OF_ADDRESS \(line)")
        Attachment.record(Data(line.utf8), named: "term-of-address.txt")
    }

    // MARK: - Scripts

    @Test(arguments: CreatorInputsDeviceTests.arguments)
    func writesTheCase(_ argument: Argument) async throws {
        KeepScreenAwake.enable()
        let service: ScriptAIService = switch argument.route {
        case .app: ScriptAIService()
        case .device: ScriptAIService(usesPrivateCloudCompute: false)
        case .cloud: ScriptAIService(preferredModel: .privateCloud)
        }
        guard service.availability.onDevice || service.availability.privateCloud else {
            try Test.cancel("Apple Intelligence isn't available: \(service.availability.reason ?? "unknown")")
        }
        if argument.route == .cloud, !service.availability.privateCloud {
            try Test.cancel("Private Cloud Compute isn't available: \(service.availability.reason ?? "unknown")")
        }
        #if canImport(UIKit)
        try #require(UIApplication.shared.applicationState == .active, "The iPhone must be unlocked with the screen on")
        #endif
        var written = 0
        for (index, idea) in argument.item.ideas.enumerated() {
            let request = Self.request(for: idea, item: argument.item)
            #expect(request.voice != nil, "\(argument.item.id): the voice is in the request")
            let started = ContinuousClock.now
            var script: GeneratedScript?
            var failure: String?
            for attempt in 1...3 {
                do {
                    script = try await service.generate(request)
                    failure = nil
                    break
                } catch ScriptAIError.rateLimited where attempt < 3 {
                    try? await Task.sleep(for: .seconds(30))
                } catch {
                    failure = "\(error)"
                    break
                }
            }
            let sample = Sample(
                caseID: argument.item.id, route: argument.route.rawValue, model: script?.model.map { "\($0)" }, ideaIndex: index, idea: idea,
                title: script?.title, text: script?.text, failure: failure, seconds: started.duration(to: .now).inSeconds,
                needsFactCheck: script?.needsFactCheck
            )
            if sample.text?.isEmpty == false { written += 1 }
            let data = try Self.encoder.encode(sample)
            print("CREATOR_INPUTS_SAMPLE " + (String(bytes: data, encoding: .utf8) ?? ""))
            Attachment.record(data, named: "creator-inputs-\(argument.item.id)-\(argument.route.rawValue)-\(index).json")
            try await Task.sleep(for: .seconds(3))
        }
        #expect(written > 0, "\(argument.testDescription): at least one script was written")
    }

    static func request(for idea: String, item: Case) -> ScriptRequest {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile = item.profile
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: service, scriptLanguage: nil, interfaceLanguage: .english,
            preferredLanguages: [item.preferredLanguage]
        )
        return factory.request(idea: idea, platform: .tiktok, format: nil)
    }

    nonisolated private static func profile(
        role: CreatorRole, niches: [Niche], sounds: [VoiceSound], phrases: [String] = [], openings: [String] = [], endings: [String] = []
    ) -> CreatorProfile {
        CreatorProfile(
            niches: niches, phrases: phrases, role: role, sounds: sounds, confirmedVoiceSteps: [.tone],
            openings: openings, endings: endings
        )
    }
}
