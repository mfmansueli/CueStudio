//
//  UltraStudyCreators.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// The creators the Ultra study writes for, invented (never a real creator): the three of the quality measurement (`QualityProfiles`: a
/// Brazilian beauty creator, an English fitness coach, a Spanish ceramics shop that speaks as a team) and four Brazilian ones for the topics
/// and registers they don't cover (money, filming with a phone, a consultant on LinkedIn, home cooking). Each with My Cue Voice answered in
/// full, half-way, or turned off (`QualityProfile.Condition`).
nonisolated enum UltraStudyCreators {
    struct Unknown: Error, CustomStringConvertible {
        let key: String
        var description: String { "No study creator named \(key)" }
    }

    static func profile(_ key: String, _ condition: QualityProfile.Condition) throws -> CreatorProfile {
        let pair: (full: CreatorProfile, half: CreatorProfile)
        switch key {
        case "pt-beauty": pair = (QualityProfiles.portuguese.full, QualityProfiles.portuguese.half)
        case "en-fitness": pair = (QualityProfiles.english.full, QualityProfiles.english.half)
        case "es-ceramics": pair = (QualityProfiles.spanish.full, QualityProfiles.spanish.half)
        case "pt-money": pair = (money, moneyHalf)
        case "pt-filming": pair = (filming, filmingHalf)
        case "pt-consultant": pair = (consultant, consultantHalf)
        case "pt-cooking": pair = (cooking, cookingHalf)
        default: throw Unknown(key: key)
        }
        switch condition {
        case .full: return pair.full
        case .half: return pair.half
        case .none:
            var plain = pair.half
            plain.usesVoiceInAI = false
            return plain
        }
    }

    // MARK: - Money and habits for young adults

    static let money = CreatorProfile(
        niches: [.finance], phrases: ["Bora lá"], role: .educator, sounds: [.casual, .confident], confirmedVoiceSteps: [.audience, .tone],
        openings: ["Mistake to avoid"], endings: ["Save this"], formats: [.list, .mythFact],
        style: VoiceDelivery(energy: .high, sentences: .short, words: .plain, swearing: .never),
        avoid: ["Promessas de enriquecimento rápido", "Indicar ações ou criptomoedas"],
        reach: VoiceReach(platforms: [.tiktok, .reels], length: .thirtyToSixty, humor: .little), audienceLevel: .new,
        examples: [VoiceExample(text: "Bora lá. Você não precisa ganhar mais pra começar a guardar. Precisa saber pra onde o dinheiro vai. Anota tudo por uma semana e me conta o que te assustou.")],
        topicDetails: ["finance": ["Reserva de emergência", "Orçamento", "Dívidas"]], audienceGroup: .youngAdults,
        audienceNote: "jovens adultos começando a organizar a rotina e o dinheiro", watchReasons: [.learn, .solveProblem],
        contentGoals: [.teach, .grow], speaksAs: .i,
        approvedSamples: [VoiceExample(text: "Bora lá. Cartão de crédito não é renda extra. Se a fatura passa de um terço do seu salário, o problema já começou. Corta um gasto fixo essa semana e vê a diferença no mês que vem.", source: "My scripts")]
    )

    static let moneyHalf = CreatorProfile(
        niches: [.finance], phrases: ["Bora lá"], role: .educator, sounds: [.casual], confirmedVoiceSteps: [.audience, .tone], speaksAs: .i
    )

    // MARK: - Filming with a phone at home

    static let filming = CreatorProfile(
        niches: [.education, .tech], customTopics: ["Gravar vídeos com o celular"], phrases: ["Simbora"], role: .educator,
        sounds: [.casual, .confident], confirmedVoiceSteps: [.audience, .tone], formats: [.tutorial],
        style: VoiceDelivery(energy: .balanced, sentences: .short, words: .plain, swearing: .never), avoid: ["Promessas exageradas"],
        reach: VoiceReach(platforms: [.tiktok, .shorts], length: .oneToThree, humor: .little), audienceLevel: .new,
        examples: [VoiceExample(text: "Simbora. Antes de comprar microfone, desliga o ventilador e grava perto da cortina. Metade do eco some de graça.")],
        customTags: ["gravar em casa"], topicDetails: ["Gravar vídeos com o celular": ["Luz", "Som", "Teleprompter"]],
        audienceNote: "criadores pequenos que gravam com o celular em casa, sem equipe", watchReasons: [.learn, .solveProblem],
        contentGoals: [.teach, .community], speaksAs: .i
    )

    static let filmingHalf = CreatorProfile(
        niches: [.education], customTopics: ["Gravar vídeos com o celular"], phrases: ["Simbora"], role: .educator, sounds: [.casual],
        confirmedVoiceSteps: [.audience, .tone], speaksAs: .i
    )

    // MARK: - A consultant on LinkedIn

    static let consultant = CreatorProfile(
        niches: [.business], role: .expert, sounds: [.professional, .confident], vocabulary: .professional,
        defaultPlatform: .linkedin, confirmedVoiceSteps: [.audience, .tone], formats: [.opinion, .story],
        style: VoiceDelivery(energy: .calm, sentences: .mixed, words: .expertTerms, swearing: .never), avoid: ["Clichês de coach", "Emojis"],
        reach: VoiceReach(platforms: [.linkedin], length: .oneToThree, humor: .noHumor), audienceLevel: .experienced,
        topicDetails: ["business": ["Gestão de equipes", "Pequenas empresas"]], audienceGroup: .businessOwners,
        audienceNote: "donos de pequenas empresas e gestores", watchReasons: [.learn, .solveProblem], contentGoals: [.winClients, .teach],
        credential: "consultora de gestão há 12 anos", speaksAs: .i
    )

    static let consultantHalf = CreatorProfile(
        niches: [.business], role: .expert, sounds: [.professional], vocabulary: .professional, defaultPlatform: .linkedin,
        confirmedVoiceSteps: [.audience, .tone], speaksAs: .i
    )

    // MARK: - Home cooking with humor

    static let cooking = CreatorProfile(
        niches: [.food], phrases: ["Olha que delícia"], role: .personal, sounds: [.funny, .casual], confirmedVoiceSteps: [.audience, .tone],
        formats: [.story, .tutorial], style: VoiceDelivery(energy: .high, sentences: .short, words: .someSlang, swearing: .never),
        reach: VoiceReach(platforms: [.reels, .tiktok], length: .thirtyToSixty, humor: .lot), audienceLevel: .new,
        topicDetails: ["food": ["Comida caseira", "Receitas baratas"]], audienceGroup: .youngAdults,
        audienceNote: "gente que mora sozinha e quer cozinhar sem gastar muito", watchReasons: [.laugh, .learn],
        contentGoals: [.entertain, .grow], speaksAs: .i
    )

    static let cookingHalf = CreatorProfile(
        niches: [.food], phrases: ["Olha que delícia"], role: .personal, sounds: [.funny], confirmedVoiceSteps: [.audience, .tone], speaksAs: .i
    )
}
