//
//  QualityProfiles.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The creators the script-quality measurement writes for (`ScriptQualityDeviceTests`), one per language the owner reads (English, Brazilian
/// Portuguese, Spanish), each with My Cue Voice answered in full (every question, imported writing, a pasted example, an approved script) and
/// half-way (the essentials a creator answers in the first minute), so a change is judged on what both kinds of creator get. Invented, not any
/// real creator.
nonisolated struct QualityProfile: Sendable, CustomTestStringConvertible {
    /// How much of My Cue Voice is answered: everything, the essentials, or the voice off.
    enum Condition: String, CaseIterable, Codable, Sendable {
        case full, half, none
    }

    let language: CueLanguage
    let full: CreatorProfile
    let half: CreatorProfile
    /// Two free ideas (one that promises a number of things) and a Find inspiration brief, in the language.
    let ideas: [String]
    let brief: IdeaBrief
    /// What the creator noted lately (their Logbook): the ideas grow from it.
    let notes: [String]

    var testDescription: String { language.rawValue }

    func profile(_ condition: Condition) -> CreatorProfile {
        switch condition {
        case .full: full
        case .half: half
        case .none: { var plain = half; plain.usesVoiceInAI = false; return plain }()
        }
    }

    /// The ideas the run writes: the two free ones, then the brief as "Start with it" puts it in the composer.
    var cases: [(idea: String, brief: IdeaBrief?)] {
        ideas.map { ($0, nil) } + [(brief.composerText, brief)]
    }
}

nonisolated enum QualityProfiles {
    static let all = [english, portuguese, spanish]

    // MARK: - English: a fitness coach

    static let english = QualityProfile(
        language: .english,
        full: complete(
            CreatorProfile(
                niches: [.fitness, .wellness], phrases: ["Okay, real talk."], role: .expert, sounds: [.energetic, .confident],
                confirmedVoiceSteps: [.audience, .tone], openings: ["Question"], endings: ["Save this"], formats: [.list, .tutorial],
                style: VoiceDelivery(energy: .high, sentences: .short, words: .plain, swearing: .never), avoid: ["Hype words", "Medical claims"],
                reach: VoiceReach(platforms: [.tiktok, .reels], length: .thirtyToSixty, humor: .little), audienceLevel: .new,
                examples: [VoiceExample(text: "You don't need a gym to get strong. You need a plan you can repeat. Twenty minutes, a mat, and two dumbbells. Try it this week and tell me how it feels.")],
                customTags: ["no-equipment workouts"], topicDetails: ["fitness": ["Home workouts", "Mobility"]], audienceGroup: .youngAdults,
                watchReasons: [.learn, .solveProblem], contentGoals: [.teach, .grow], credential: "certified personal trainer", speaksAs: .i,
                approvedSamples: [VoiceExample(text: "Is your back sore after leg day? Okay, real talk. You're skipping the hinge. Push your hips back, keep your chest proud, and go slow. Do ten of these before every workout. Save this for leg day.", source: "My scripts")]
            ),
            writing: WritingSamples.maya
        ),
        half: CreatorProfile(
            niches: [.fitness], phrases: ["Okay, real talk."], role: .expert, sounds: [.energetic], confirmedVoiceSteps: [.audience, .tone],
            style: VoiceDelivery(sentences: .short)
        ),
        ideas: ["3 mistakes that ruin your home workouts", "Why rest days make you stronger"],
        brief: IdeaBrief(
            subject: "The warm-up most people skip", angle: "Show a five-minute warm-up anyone can do at home.",
            openingLine: "Your workout starts before the first squat.", language: "en", angleKind: IdeaAngle.tutorial.rawValue, topicKey: "fitness"
        ),
        notes: ["Mobility routine for people who sit all day", "Why I stopped doing cardio first"]
    )

    // MARK: - Brazilian Portuguese: a beauty creator

    static let portuguese = QualityProfile(
        language: .portugueseBrazil,
        full: complete(
            CreatorProfile(
                niches: [.beauty], phrases: ["Fala, galera!"], role: .personal, sounds: [.casual, .funny], confirmedVoiceSteps: [.audience, .tone],
                openings: ["Mistake to avoid"], endings: ["Comment your answer"], formats: [.list],
                style: VoiceDelivery(energy: .high, sentences: .short, words: .someSlang, swearing: .never), avoid: ["Medical claims", "Clickbait"],
                reach: VoiceReach(platforms: [.tiktok], length: .thirtyToSixty, humor: .little), audienceLevel: .some,
                examples: [VoiceExample(text: "Fala, galera! Sabe aquele corretivo que craquela? Tipo, o problema é a quantidade. Usa só um pontinho e espalha com o dedo. Me conta se mudou!")],
                topicDetails: ["beauty": ["Skincare barato", "Maquiagem rápida"]], audienceGroup: .youngAdults, watchReasons: [.learn, .decideToBuy],
                contentGoals: [.grow, .entertain], speaksAs: .i,
                approvedSamples: [VoiceExample(text: "Fala, galera! Você tá lavando o rosto errado. Tipo, água quente demais resseca tudo. Usa água morna, sabonete suave e seca sem esfregar. Comenta aqui se você fazia isso!", source: "My scripts")]
            ),
            writing: WritingSamples.rafa
        ),
        half: CreatorProfile(
            niches: [.beauty], phrases: ["Fala, galera!"], role: .personal, sounds: [.casual], confirmedVoiceSteps: [.audience, .tone]
        ),
        ideas: ["3 erros que estragam sua pele de manhã", "Por que protetor solar barato também funciona"],
        brief: IdeaBrief(
            subject: "A maquiagem de 5 minutos para o dia a dia", angle: "Mostre uma maquiagem completa em cinco passos rápidos.",
            openingLine: "Dá pra ficar pronta em cinco minutos, sério.", language: "pt", angleKind: IdeaAngle.tutorial.rawValue, topicKey: "beauty"
        ),
        notes: ["Rotina de skincare com três produtos de farmácia", "Batom que dura o dia inteiro existe?"]
    )

    // MARK: - Spanish: a small ceramics shop that speaks as a team

    static let spanish = QualityProfile(
        language: .spanish,
        full: complete(
            CreatorProfile(
                customTopics: ["Cerámica artesanal"], phrases: ["Hola, familia."], role: .business, sounds: [.warmCalm, .casual],
                confirmedVoiceSteps: [.audience, .tone], openings: ["Story opener"], endings: ["Follow for more"], formats: [.story, .tutorial],
                style: VoiceDelivery(energy: .balanced, sentences: .mixed, words: .plain, swearing: .never), avoid: ["Hype words"],
                reach: VoiceReach(platforms: [.reels], length: .thirtyToSixty, humor: .noHumor), audienceLevel: .new,
                examples: [VoiceExample(text: "Hola, familia. Cada taza que sale de nuestro taller pasa por nuestras manos tres veces. Nosotros la tornamos, la esmaltamos y la revisamos antes de enviarla.")],
                voiceTopics: [.business], topicDetails: ["Cerámica artesanal": ["Tazas", "Esmaltes"]], audienceGroup: .localCommunity,
                watchReasons: [.getInspired, .decideToBuy], contentGoals: [.sell, .community], speaksAs: .we,
                approvedSamples: [VoiceExample(text: "Hola, familia. Hoy les contamos por qué nuestras tazas tardan dos semanas. Nosotros dejamos secar cada pieza despacio, porque si la apuramos, se agrieta en el horno. Síguenos para ver el proceso completo.", source: "My scripts")]
            ),
            writing: WritingSamples.lucia
        ),
        half: CreatorProfile(
            customTopics: ["Cerámica artesanal"], phrases: ["Hola, familia."], role: .business, sounds: [.warmCalm],
            confirmedVoiceSteps: [.audience, .tone], speaksAs: .we
        ),
        ideas: ["Tres errores al abrir una tienda pequeña", "Por qué hacemos cada pieza a mano"],
        brief: IdeaBrief(
            subject: "Cómo elegir una taza que dure años", angle: "Explica tres señales de una taza de cerámica bien hecha.",
            openingLine: "No todas las tazas de cerámica son iguales.", language: "es", angleKind: IdeaAngle.tutorial.rawValue, topicKey: "Cerámica artesanal"
        ),
        notes: ["Clientes que piden tazas personalizadas", "El esmalte azul que siempre se agota"]
    )

    /// The profile with the creator's writing imported ("Import my writing"): the excerpts and the measured habits.
    private static func complete(_ profile: CreatorProfile, writing: [String]) -> CreatorProfile {
        var profile = profile
        let analysis = WritingAnalyzer.analyze(writing.map { WritingPiece(text: $0) })
        profile.excerpts = Array(analysis.excerpts.prefix(VoiceExcerpt.limit))
        profile.fingerprint = analysis.fingerprint
        return profile
    }
}
