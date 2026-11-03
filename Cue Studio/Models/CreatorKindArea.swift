//
//  CreatorKindArea.swift
//  Cue Studio
//

import Foundation

/// The areas the kinds of creator are grouped in (the owner, 03/11/2026: grouped, so a creator sees where to look): each kind is in one or two
/// (a beauty creator is a creator and is beauty), the areas with the most creators first. "What kind of creator are you?" opens on the most
/// common kinds and shows the areas to browse the others (`CreatorKindPicker`).
nonisolated enum CreatorKindArea: String, CaseIterable, Identifiable, Sendable {
    case creators, business, health, beautyFashion, fitnessSports, food, education, lawMoney, entertainment, tech, artHome, travelEvents
    case faithCauses, animalsFarming, cars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .creators: String(localized: "Creators & influencers")
        case .business: String(localized: "Business & sales")
        case .health: String(localized: "Health & wellness")
        case .beautyFashion: String(localized: "Beauty & fashion")
        case .fitnessSports: String(localized: "Fitness & sports")
        case .food: String(localized: "Food")
        case .education: String(localized: "Education")
        case .lawMoney: String(localized: "Law, money & property")
        case .entertainment: String(localized: "Entertainment & media")
        case .tech: String(localized: "Technology")
        case .artHome: String(localized: "Art, home & trades")
        case .travelEvents: String(localized: "Travel & events")
        case .faithCauses: String(localized: "Faith & causes")
        case .animalsFarming: String(localized: "Animals & farming")
        case .cars: String(localized: "Cars & transport")
        }
    }

    var systemImage: String {
        switch self {
        case .creators: "video"
        case .business: "briefcase"
        case .health: "stethoscope"
        case .beautyFashion: "hanger"
        case .fitnessSports: "figure.run"
        case .food: "fork.knife"
        case .education: "graduationcap"
        case .lawMoney: "building.columns"
        case .entertainment: "theatermasks"
        case .tech: "laptopcomputer"
        case .artHome: "paintpalette"
        case .travelEvents: "airplane"
        case .faithCauses: "hands.sparkles"
        case .animalsFarming: "pawprint"
        case .cars: "car"
        }
    }

    /// The area's kinds, the ones that cover the most creators first.
    var kinds: [CreatorKind] {
        let ids = Set(Self.members[self] ?? [])
        return CreatorKind.all.filter { ids.contains($0.id) }
    }

    /// The area a kind is in.
    static func of(_ kind: CreatorKind) -> CreatorKindArea? {
        allCases.first { (members[$0] ?? []).contains(kind.id) }
    }

    private static let members: [CreatorKindArea: [String]] = [
        .creators: [
            "contentCreator", "lifestyleCreator", "influencer", "ugcCreator", "beautyCreator", "fitnessCreator", "vlogger", "parentCreator",
            "travelCreator", "fashionCreator", "productReviewer", "student", "relationshipCreator", "healthJourney", "expat", "creatorOver50",
            "beginner",
        ],
        .business: [
            "smallBusinessOwner", "entrepreneur", "socialMediaManager", "consultant", "onlineStoreOwner", "affiliateMarketer", "businessCoach",
            "professionalSharingJob", "corporateProfessional", "executive", "marketer", "agencyOwner", "freelancer", "brandTeam", "liveSeller",
            "salesperson", "recruiter", "motivationalSpeaker",
        ],
        .health: [
            "nutritionist", "lifeCoach", "doctor", "psychologist", "dentist", "esthetician", "nurse", "physicalTherapist", "clinic", "pharmacist",
            "speechTherapist", "healthJourney", "holisticTherapist",
        ],
        .beautyFashion: [
            "beautyCreator", "makeupArtist", "fashionCreator", "esthetician", "hairStylist", "barber", "nailTech", "lashBrowArtist", "personalStylist",
            "clothingStoreOwner",
        ],
        .fitnessSports: ["personalTrainer", "fitnessCreator", "gymOwner", "yogaInstructor", "athlete", "sportsCommentator", "sportsCoach"],
        .food: ["homeCook", "foodReviewer", "chef", "baker", "restaurantOwner"],
        .education: [
            "teacher", "courseCreator", "languageTeacher", "historyExplainer", "scienceCommunicator", "examTutor", "school", "researcher",
        ],
        .lawMoney: [
            "lawyer", "realEstateAgent", "financeCreator", "financialAdvisor", "accountant", "investor", "insuranceAgent", "publicServant",
        ],
        .entertainment: [
            "comedian", "gamer", "musician", "commentator", "newsCreator", "podcaster", "storyteller", "dancer", "actor", "reactionCreator",
            "filmReviewer", "bookCreator", "writer", "trueCrimeCreator",
        ],
        .tech: ["techReviewer", "developer", "aiCreator", "techRepair", "engineer"],
        .artHome: [
            "tattooArtist", "artist", "designer", "photographer", "crafter", "architect", "homeCreator", "organizer", "builder", "tradesperson",
            "gardener",
        ],
        .travelEvents: ["travelCreator", "travelAgent", "host", "eventPlanner"],
        .faithCauses: ["pastor", "faithCreator", "church", "spiritualGuide", "nonprofit", "activist"],
        .animalsFarming: ["petCreator", "dogTrainer", "petBusiness", "veterinarian", "farmer", "agronomist"],
        .cars: ["mechanic", "carCreator", "carDealer", "driver"],
    ]
}
