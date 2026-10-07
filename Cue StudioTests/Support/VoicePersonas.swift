//
//  VoicePersonas.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// The twelve made-up creators My Cue Voice is measured on (plan §5 · stage 0, §6), each with three ideas, plus two of them in
/// another language to exercise the language checks. Every profile is what the app can hold *today*: the fields added later are
/// given to the same people in `VoicePersona+Enriched`, so before and after talk about the same creator.
///
/// The `styles` of a profile are left at the app's default (short sentences, conversational): that is what nearly every real
/// profile carries, and it is part of what the measurements must show.
nonisolated enum VoicePersonas {
    /// The twelve English personas, in a fixed order.
    static let all: [VoicePersona] = [
        yogaTeacher, saasFounder, nurseEducator, comedian, momCreator, barbershop,
        financeCoach, newsCommentator, ugcCreator, rescueNonprofit, languageTeacher, realEstateAgent,
    ]

    /// Two of them in another language (Brazilian Portuguese, Spanish): a creator who writes in a language the instructions aren't in.
    static let languageVariants: [VoicePersona] = [momCreatorPortuguese, financeCoachSpanish]

    /// Three ideas that suit any creator, written for everyone: the same idea in the voice of different people is what tells whether the voices
    /// are different (plan §6.3). Written on top of each persona's own ideas, in a run named with `shared`.
    static let sharedIdeas = [
        "The biggest mistake beginners make",
        "What I would tell myself a year ago",
        "One thing I stopped doing and never regretted",
    ]

    static func persona(_ id: String) -> VoicePersona? {
        (all + languageVariants).first { $0.id == id }
    }

    // MARK: - Words that stand for what a creator avoids

    static let medicalClaims = ["cure", "cures", "heals", "treats your", "guaranteed to"]
    static let hype = ["game-changer", "game changer", "insane", "mind-blowing", "unbelievable", "life-changing", "revolutionary"]
    static let clickbait = ["you won't believe", "shocking", "what happens next", "doctors hate"]
    static let politics = ["democrat", "republican", "liberal", "conservative", "election", "vote for", "left-wing", "right-wing"]

    // MARK: - The twelve

    static let yogaTeacher = VoicePersona(
        id: "yoga-teacher",
        summary: "A yoga teacher: calm and warm, plain words, never promises a medical result.",
        language: .english,
        profile: profile(
            role: .expert, niches: [.fitness], vocabulary: .simple, level: .new, sounds: [.warmCalm, .educational],
            style: VoiceDelivery(energy: .calm, sentences: .mixed, words: .plain, swearing: .never),
            phrases: ["Breathe in."], openings: ["Question"], endings: ["Save this"], formats: [.tutorial],
            avoid: ["Medical claims", "Hype words"]
        ),
        ideas: [
            "Why your shoulders hurt after a day at a desk and a two-minute fix",
            "How to start a morning practice when you hate mornings",
            "Three myths about flexibility I keep hearing in class",
        ],
        pronoun: .i, forbiddenTerms: medicalClaims + hype, topicTerms: ["yoga", "breath", "stretch", "pose", "mat", "shoulder", "practice"]
    )

    static let saasFounder = VoicePersona(
        id: "saas-founder",
        summary: "A SaaS founder who says “we”: confident, direct, knows the field, no hype.",
        language: .english,
        profile: profile(
            role: .business, niches: [.tech, .productivity], vocabulary: .technical, level: .experienced, sounds: [.confident, .professional],
            style: VoiceDelivery(energy: .balanced, sentences: .short, words: .expertTerms, swearing: .never),
            phrases: ["Here's what we shipped."], openings: ["Bold claim"], endings: ["Follow for more"], formats: [.opinion, .list],
            avoid: ["Hype words", "Clickbait"]
        ),
        ideas: [
            "Why we killed our most requested feature",
            "What we learned from shipping every week for a year",
            "How we cut our onboarding from fourteen steps to three",
        ],
        pronoun: .we, forbiddenTerms: hype + clickbait, topicTerms: ["ship", "product", "customer", "feature", "team", "onboarding", "users"]
    )

    static let nurseEducator = VoicePersona(
        id: "nurse-educator",
        summary: "A nurse who teaches: warm but exact, explains in plain words, never diagnoses on camera.",
        language: .english,
        profile: profile(
            role: .educator, niches: [.wellness], customTopics: ["Nursing"], vocabulary: .simple, level: .some,
            sounds: [.educational, .warmCalm],
            style: VoiceDelivery(energy: .balanced, sentences: .mixed, words: .plain, swearing: .never),
            phrases: ["Let's break it down."], openings: ["Story opener"], endings: ["Comment your answer"], formats: [.list, .mythFact],
            avoid: ["Medical claims", "diagnose"]
        ),
        ideas: [
            "What to do when a coworker asks you to skip a safety check",
            "Three things I wish I knew in my first year of nursing",
            "How to read a blood pressure number without panicking",
        ],
        pronoun: .i, forbiddenTerms: medicalClaims + ["diagnose", "you have a "],
        topicTerms: ["nurse", "nursing", "patient", "shift", "hospital", "care", "blood pressure"]
    )

    static let comedian = VoicePersona(
        id: "comedian",
        summary: "A comedian: fast, playful and dry, mild swearing is fine, stays out of politics.",
        language: .english,
        profile: profile(
            role: .entertainer, niches: [.lifestyle], vocabulary: .genZ, level: .experienced, sounds: [.funny, .dry],
            style: VoiceDelivery(energy: .high, sentences: .short, words: .someSlang, swearing: .mild),
            phrases: ["Anyway."], openings: ["POV"], endings: ["Follow for more"], formats: [.story, .pov],
            avoid: ["Politics"], reach: VoiceReach(platforms: [.tiktok, .reels], length: .thirtyToSixty, humor: .lot)
        ),
        ideas: [
            "Things I pretended to understand as an adult",
            "My landlord and the great thermostat war",
            "Why every group chat has the same five people",
        ],
        pronoun: .i, forbiddenTerms: politics, topicTerms: ["my", "honestly", "literally", "friend", "chat", "landlord", "adult"]
    )

    static let momCreator = VoicePersona(
        id: "mom-creator",
        summary: "A mom creator: warm, practical, talks to other parents, no medical advice.",
        language: .english,
        profile: profile(
            role: .personal, niches: [.parenting, .food], vocabulary: .simple, level: .some, sounds: [.warmCalm, .casual],
            style: VoiceDelivery(energy: .balanced, sentences: .short, words: .plain, swearing: .never),
            phrases: ["Mama moment."], openings: ["Story opener"], endings: ["Comment your answer"], formats: [.list, .story],
            avoid: ["Medical claims"]
        ),
        ideas: [
            "How I get two toddlers out the door in under ten minutes",
            "The dinner my picky eater actually finishes",
            "What nobody tells you about the first month with a newborn",
        ],
        pronoun: .i, forbiddenTerms: medicalClaims, topicTerms: ["kids", "toddler", "dinner", "mom", "baby", "family", "morning"]
    )

    static let barbershop = VoicePersona(
        id: "barbershop",
        summary: "A local barbershop that says “we”: friendly, confident, talks to the neighbourhood, sends people to book.",
        language: .english,
        profile: profile(
            role: .business, niches: [.fashion], customTopics: ["Barbershop"], vocabulary: .simple, level: .some,
            sounds: [.casual, .confident],
            style: VoiceDelivery(energy: .balanced, sentences: .short, words: .plain, swearing: .never),
            phrases: ["Fresh cut, fresh start."], openings: ["Question"], endings: ["Link in bio"], formats: [.tutorial, .list],
            avoid: ["Clickbait"]
        ),
        ideas: [
            "How to ask your barber for exactly the cut you want",
            "Three signs it's time to trim your beard",
            "Why Saturday morning is our busiest slot and how to skip the wait",
        ],
        pronoun: .we, forbiddenTerms: clickbait, topicTerms: ["barber", "cut", "beard", "shop", "hair", "book", "chair"]
    )

    static let financeCoach = VoicePersona(
        id: "finance-coach",
        summary: "A personal-finance coach: plain words for beginners, short sentences, never promises returns.",
        language: .english,
        profile: profile(
            role: .expert, niches: [.finance], vocabulary: .simple, level: .new, sounds: [.educational, .professional],
            style: VoiceDelivery(energy: .balanced, sentences: .short, words: .plain, swearing: .never),
            phrases: ["Pay yourself first."], openings: ["Surprising fact"], endings: ["Save this"], formats: [.list, .tutorial],
            avoid: ["Hype words", "Clickbait", "get rich quick"]
        ),
        ideas: [
            "How to build a 500 dollar emergency fund in 90 days",
            "Why your savings account is losing money",
            "Three money habits I'd teach my younger self",
        ],
        pronoun: .i, forbiddenTerms: hype + clickbait + ["get rich quick", "risk-free", "guaranteed return"],
        topicTerms: ["money", "save", "savings", "budget", "fund", "debt", "income"]
    )

    static let newsCommentator = VoicePersona(
        id: "news-commentator",
        summary: "A news commentator: measured, dry, long sentences that build an argument, no hype.",
        language: .english,
        profile: profile(
            role: .news, niches: [.tech], customTopics: ["Tech policy"], vocabulary: .professional, level: .experienced, sounds: [.professional, .dry],
            style: VoiceDelivery(energy: .calm, sentences: .long, words: .expertTerms, swearing: .never),
            phrases: [], openings: ["Surprising fact"], endings: ["Comment your answer"], formats: [.opinion, .mythFact],
            avoid: ["Hype words"]
        ),
        ideas: [
            "What the new data privacy rules actually change for you",
            "Why the headline about the chip shortage misses the point",
            "The one number behind this week's market swing",
        ],
        pronoun: .i, forbiddenTerms: hype, topicTerms: ["policy", "rules", "market", "data", "regulation", "number", "headline"]
    )

    static let ugcCreator = VoicePersona(
        id: "ugc-creator",
        summary: "A UGC creator who reviews products for brands, speaks as herself (“I”), honest and conversational.",
        language: .english,
        profile: profile(
            role: .brands, niches: [.beauty], vocabulary: .genZ, level: .some, sounds: [.casual, .energetic],
            style: VoiceDelivery(energy: .high, sentences: .short, words: .someSlang, swearing: .never),
            phrases: ["Okay, so."], openings: ["Question"], endings: ["Try it and tell me"], formats: [.review, .list],
            avoid: ["Hype words", "Medical claims"]
        ),
        ideas: [
            "Honest first impressions of a reusable water bottle after thirty days",
            "Unboxing the skincare set my followers kept asking about",
            "Three reasons I switched my laundry detergent",
        ],
        pronoun: .i, forbiddenTerms: hype + medicalClaims, topicTerms: ["honest", "review", "tried", "weeks", "product", "bottle", "skin"]
    )

    static let rescueNonprofit = VoicePersona(
        id: "rescue-nonprofit",
        summary: "An animal-rescue nonprofit that says “we”: warm, hopeful, asks for help without guilt.",
        language: .english,
        profile: profile(
            role: .community, niches: [.lifestyle], customTopics: ["Animal rescue"], vocabulary: .simple, level: .some, sounds: [.warmCalm, .energetic],
            style: VoiceDelivery(energy: .balanced, sentences: .mixed, words: .plain, swearing: .never),
            phrases: ["Every dog deserves a home."], openings: ["Story opener"], endings: ["Follow for more"], formats: [.story],
            avoid: ["Politics", "Clickbait"]
        ),
        ideas: [
            "How a 20 dollar donation feeds a shelter dog for a month",
            "Meet the volunteers who rescued forty dogs this winter",
            "Why we need foster homes before the summer",
        ],
        pronoun: .we, forbiddenTerms: politics + clickbait, topicTerms: ["dog", "dogs", "shelter", "rescue", "foster", "donation", "volunteers"]
    )

    static let languageTeacher = VoicePersona(
        id: "language-teacher",
        summary: "A Spanish teacher on camera: encouraging, short sentences, mixes in a Spanish catchphrase.",
        language: .english,
        profile: profile(
            role: .educator, niches: [.education], customTopics: ["Spanish"], vocabulary: .simple, level: .new,
            sounds: [.casual, .educational],
            style: VoiceDelivery(energy: .high, sentences: .short, words: .plain, swearing: .never),
            phrases: ["¡Vamos!"], openings: ["Question"], endings: ["Try it and tell me"], formats: [.tutorial, .list],
            avoid: ["Hype words"]
        ),
        ideas: [
            "Three Spanish phrases that make you sound less like a tourist",
            "Why you forget words the day after you learn them",
            "How to practice speaking when you have nobody to talk to",
        ],
        pronoun: .i, forbiddenTerms: hype, topicTerms: ["spanish", "words", "phrases", "practice", "learn", "speak", "language"]
    )

    static let realEstateAgent = VoicePersona(
        id: "real-estate-agent",
        summary: "A real-estate agent: confident and friendly, talks to first-time buyers, no pressure tactics.",
        language: .english,
        profile: profile(
            role: .expert, niches: [.finance], customTopics: ["Real estate"], vocabulary: .simple, level: .new, sounds: [.confident, .casual],
            style: VoiceDelivery(energy: .balanced, sentences: .mixed, words: .plain, swearing: .never),
            phrases: ["Here's the thing about homes."], openings: ["Bold claim"], endings: ["Link in bio"], formats: [.list, .tutorial],
            avoid: ["Clickbait", "Hype words", "once in a lifetime"]
        ),
        ideas: [
            "What to check in the first five minutes of a home viewing",
            "Why I tell first-time buyers to wait on the open house",
            "Three costs that show up after closing that nobody mentions",
        ],
        pronoun: .i, forbiddenTerms: clickbait + hype + ["once in a lifetime", "act now"],
        topicTerms: ["home", "buyers", "house", "closing", "offer", "viewing", "agent"]
    )

    // MARK: - The same creators in another language

    static let momCreatorPortuguese = VoicePersona(
        id: "mom-creator-pt-br",
        summary: "The mom creator, writing in Brazilian Portuguese.",
        language: .portugueseBrazil,
        profile: profile(
            role: .personal, niches: [.parenting, .food], vocabulary: .simple, level: .some, sounds: [.warmCalm, .casual],
            style: VoiceDelivery(energy: .balanced, sentences: .short, words: .plain, swearing: .never),
            phrases: ["Momento de mãe."], openings: ["Story opener"], endings: ["Comment your answer"], formats: [.list, .story],
            avoid: ["Medical claims"]
        ),
        ideas: [
            "Como eu saio de casa com dois filhos pequenos em dez minutos",
            "O jantar que meu filho enjoado realmente come até o fim",
            "O que ninguém conta sobre o primeiro mês com um recém-nascido",
        ],
        pronoun: .i, forbiddenTerms: ["cura", "garantido", "trata sua"], topicTerms: ["filhos", "jantar", "mãe", "bebê", "família", "manhã"]
    )

    static let financeCoachSpanish = VoicePersona(
        id: "finance-coach-es",
        summary: "The finance coach, writing in Spanish.",
        language: .spanish,
        profile: profile(
            role: .expert, niches: [.finance], vocabulary: .simple, level: .new, sounds: [.educational, .professional],
            style: VoiceDelivery(energy: .balanced, sentences: .short, words: .plain, swearing: .never),
            phrases: ["Págate primero."], openings: ["Surprising fact"], endings: ["Save this"], formats: [.list, .tutorial],
            avoid: ["Hype words", "Clickbait", "get rich quick"]
        ),
        ideas: [
            "Cómo armar un fondo de emergencia de 500 dólares en 90 días",
            "Por qué tu cuenta de ahorros pierde dinero",
            "Tres hábitos de dinero que le enseñaría a mi yo más joven",
        ],
        pronoun: .i, forbiddenTerms: ["hazte rico rápido", "sin riesgo", "garantizado"],
        topicTerms: ["dinero", "ahorro", "ahorros", "presupuesto", "fondo", "deuda", "ingresos"]
    )

    // MARK: - Building a profile

    /// A profile the way the app holds it after the creator answered the four cards and a few Personality questions: the tone and
    /// the audience are confirmed, so "Write in my voice" can turn on.
    private static func profile(
        role: CreatorRole, niches: [Niche] = [], customTopics: [String] = [], vocabulary: Vocabulary, level: AudienceLevel,
        sounds: [VoiceSound], style: VoiceDelivery, phrases: [String] = [], openings: [String] = [], endings: [String] = [],
        formats: [ScriptType] = [], avoid: [String] = [], reach: VoiceReach = VoiceReach()
    ) -> CreatorProfile {
        CreatorProfile(
            niches: niches, customTopics: customTopics, phrases: phrases, role: role, sounds: sounds, vocabulary: vocabulary,
            confirmedVoiceSteps: [.audience, .tone], openings: openings, endings: endings, formats: formats,
            style: style, avoid: avoid, reach: reach, audienceLevel: level
        )
    }
}
