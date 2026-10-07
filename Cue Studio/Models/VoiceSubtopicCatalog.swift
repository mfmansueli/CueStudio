//
//  VoiceSubtopicCatalog.swift
//  Cue Studio
//

import Foundation

/// The subtopics Cue suggests under each topic (My Cue Voice · What do you talk about?): seven a topic, from which the creator keeps up to
/// `VoiceLimits.details`. A subtopic is kept as its English text (its `id`) and shown in the interface language, so a creator who changes the
/// app's language keeps what they picked; what they type is kept as typed.
nonisolated enum VoiceSubtopicCatalog {
    static func suggestions(for niche: Niche) -> [VoiceOption] {
        switch niche {
        case .fitness: [
            .entry("Strength training"),
            .entry("Running"),
            .entry("Yoga & stretching"),
            .entry("Home workouts"),
            .entry("Weight loss"),
            .entry("Nutrition basics"),
            .entry("Sleep & recovery"),
        ]
        case .food: [
            .entry("Quick weeknight meals"),
            .entry("Baking"),
            .entry("Healthy eating"),
            .entry("Meal prep"),
            .entry("Budget cooking"),
            .entry("Vegan & vegetarian"),
            .entry("Restaurant reviews"),
        ]
        case .beauty: [
            .entry("Skincare routines"),
            .entry("Makeup"),
            .entry("Hair care"),
            .entry("Nails"),
            .entry("Product reviews"),
            .entry("Men’s grooming"),
            .entry("Budget beauty"),
        ]
        case .fashion: [
            .entry("Outfit ideas"),
            .entry("Thrifting"),
            .entry("Capsule wardrobe"),
            .entry("Men’s style"),
            .entry("Sneakers"),
            .entry("Sustainable fashion"),
            .entry("Dressing for work"),
        ]
        case .finance: [
            .entry("Budgeting"),
            .entry("Saving"),
            .entry("Investing basics"),
            .entry("Getting out of debt"),
            .entry("Credit scores"),
            .entry("Side income"),
            .entry("Taxes"),
        ]
        case .tech: [
            .entry("AI tools"),
            .entry("Gadgets"),
            .entry("Apps & software"),
            .entry("Coding"),
            .entry("Phones"),
            .entry("Online safety"),
            .entry("Tech news"),
        ]
        case .travel: [
            .entry("Cheap flights"),
            .entry("Hostels & stays"),
            .entry("Solo travel"),
            .entry("City guides"),
            .entry("Road trips"),
            .entry("Packing tips"),
            .entry("Travel hacks"),
        ]
        case .productivity: [
            .entry("Time management"),
            .entry("Job hunting"),
            .entry("Interviews"),
            .entry("Remote work"),
            .entry("Note-taking"),
            .entry("Habits & routines"),
            .entry("Side projects"),
        ]
        case .parenting: [
            .entry("Newborns"),
            .entry("Toddlers"),
            .entry("School age"),
            .entry("Teens"),
            .entry("Family meals"),
            .entry("Screen time"),
            .entry("Parent self-care"),
        ]
        case .lifestyle: [
            .entry("Wake-up habits"),
            .entry("Slow mornings"),
            .entry("Productive mornings"),
            .entry("Breakfast ideas"),
            .entry("Morning workouts"),
            .entry("Journaling"),
            .entry("Evening routines"),
        ]
        case .wellness: [
            .entry("Stress relief"),
            .entry("Mindfulness"),
            .entry("Sleep"),
            .entry("Self-care"),
            .entry("Healthy habits"),
            .entry("Journaling"),
            .entry("Mental health"),
        ]
        case .education: [
            .entry("Study tips"),
            .entry("Exam prep"),
            .entry("Learning methods"),
            .entry("Online courses"),
            .entry("Science explained"),
            .entry("History"),
            .entry("Teaching"),
        ]
        }
    }

    static func suggestions(for topic: VoiceTopic) -> [VoiceOption] {
        switch topic {
        case .gaming: [
            .entry("Console games"),
            .entry("PC gaming"),
            .entry("Mobile games"),
            .entry("Game reviews"),
            .entry("Tips & strategies"),
            .entry("Esports"),
            .entry("Streaming"),
        ]
        case .realEstate: [
            .entry("Buying a home"),
            .entry("Renting"),
            .entry("Selling a home"),
            .entry("Open houses"),
            .entry("Mortgages"),
            .entry("Property investing"),
            .entry("Home staging"),
        ]
        case .musicArts: [
            .entry("Singing"),
            .entry("Guitar"),
            .entry("Piano"),
            .entry("Songwriting"),
            .entry("Drawing"),
            .entry("Painting"),
            .entry("Photography"),
        ]
        case .pets: [
            .entry("Dogs"),
            .entry("Cats"),
            .entry("Puppy training"),
            .entry("Pet health basics"),
            .entry("Adoption & rescue"),
            .entry("Aquariums"),
            .entry("Pet products"),
        ]
        case .homeDIY: [
            .entry("Decor"),
            .entry("Renovation"),
            .entry("Cleaning"),
            .entry("Organizing"),
            .entry("Furniture flips"),
            .entry("Gardening"),
            .entry("Repairs"),
        ]
        case .healthcare: [
            .entry("Nursing"),
            .entry("Dentistry"),
            .entry("Physical therapy"),
            .entry("Pharmacy"),
            .entry("Public health"),
            .entry("Women’s health"),
            .entry("Patient education"),
        ]
        case .business: [
            .entry("Small business"),
            .entry("Social media marketing"),
            .entry("Sales"),
            .entry("E-commerce"),
            .entry("Branding"),
            .entry("Freelancing"),
            .entry("Startups"),
        ]
        case .study: [
            .entry("Study techniques"),
            .entry("Exam prep"),
            .entry("University life"),
            .entry("Scholarships"),
            .entry("Note-taking"),
            .entry("Time management"),
            .entry("Study with me"),
        ]
        case .relationships: [
            .entry("Dating"),
            .entry("Marriage"),
            .entry("Friendships"),
            .entry("Communication"),
            .entry("Breakups"),
            .entry("Family"),
            .entry("Self-love"),
        ]
        case .faith: [
            .entry("Prayer"),
            .entry("Bible study"),
            .entry("Devotionals"),
            .entry("Meditation"),
            .entry("Testimonies"),
            .entry("Church life"),
            .entry("Youth ministry"),
        ]
        case .news: [
            .entry("Daily news"),
            .entry("Politics explained"),
            .entry("Business news"),
            .entry("World events"),
            .entry("Fact checks"),
            .entry("Local news"),
            .entry("Analysis"),
        ]
        case .cars: [
            .entry("Car reviews"),
            .entry("Maintenance"),
            .entry("Buying a car"),
            .entry("Motorcycles"),
            .entry("Car modification"),
            .entry("Electric vehicles"),
            .entry("Detailing"),
        ]
        case .sports: [
            .entry("Football"),
            .entry("Basketball"),
            .entry("Training tips"),
            .entry("Match analysis"),
            .entry("Cycling"),
            .entry("Combat sports"),
            .entry("Fantasy sports"),
        ]
        case .languages: [
            .entry("Spanish"),
            .entry("English"),
            .entry("French"),
            .entry("Japanese"),
            .entry("Vocabulary"),
            .entry("Grammar"),
            .entry("Speaking practice"),
        ]
        case .booksMovies: [
            .entry("Book reviews"),
            .entry("Movie reviews"),
            .entry("TV series"),
            .entry("Reading habits"),
            .entry("Recommendations"),
            .entry("Book clubs"),
            .entry("Fandoms"),
        ]
        }
    }

    /// A subtopic as it is shown: the interface language's text for one of Cue's, the creator's own text as typed.
    static func displayName(of subtopic: String) -> String {
        String(localized: String.LocalizationValue(subtopic))
    }
}

private nonisolated extension VoiceOption {
    /// An option whose id is its English text.
    static func entry(_ text: LocalizedStringResource) -> VoiceOption {
        VoiceOption(id: text.key, label: String(localized: text))
    }
}
