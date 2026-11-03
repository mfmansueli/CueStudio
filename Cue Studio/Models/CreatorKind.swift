//
//  CreatorKind.swift
//  Cue Studio
//

import Foundation

/// "What kind of creator are you?", the first question of My Cue Voice: the creator's own description out of a long list (the owner, 03/11/2026:
/// one list with search, covering from a food reviewer to a lawyer who raises awareness and wins clients), researched across platform categories,
/// creator-economy reports and creator forums. It tells the AI who is talking, in the scripts and in the ideas; its broad kind (`role`) keeps
/// what the eight roles decide (the audiences offered first, I or we).
nonisolated struct CreatorKind: Identifiable, Sendable {
    /// How it is kept (`CreatorProfile.creatorKind`).
    let id: String
    let label: LocalizedStringResource
    /// The broad kind it belongs to.
    let role: CreatorRole
    /// What the AI reads (English, whatever the interface language is).
    let promptName: String
    /// The themes such a creator most often talks about, offered first in "What do you talk about?".
    let themes: [Niche]
    /// "I" or "we" where it differs from its broad kind's (a UGC creator says "I", a church "we").
    private let speaksAs: SpeaksAs?

    private init(
        _ id: String, _ label: LocalizedStringResource, _ role: CreatorRole, _ promptName: String, themes: [Niche], speaksAs: SpeaksAs? = nil
    ) {
        self.id = id
        self.label = label
        self.role = role
        self.promptName = promptName
        self.themes = themes
        self.speaksAs = speaksAs
    }

    var title: String { String(inInterfaceLanguage: label) }

    var suggestedSpeaksAs: SpeaksAs { speaksAs ?? role.suggestedSpeaksAs }

    static func find(_ id: String?) -> CreatorKind? {
        id.flatMap { byID[$0] }
    }

    /// Every kind, the ones that cover the most creators first.
    static let all: [CreatorKind] = [
        Self("contentCreator", "Content creator", .personal, "a content creator who talks to camera about their own life and interests",
             themes: [.lifestyle]),
        Self("smallBusinessOwner", "Small business owner", .business, "the owner of a small local business talking to their customers",
             themes: [.business]),
        Self("lifestyleCreator", "Lifestyle creator", .personal, "a lifestyle creator who shares routines, opinions and daily life",
             themes: [.lifestyle, .fashion, .beauty]),
        Self("influencer", "Influencer", .personal, "an influencer who recommends things to an audience that trusts them",
             themes: [.lifestyle, .beauty, .fashion]),
        Self("entrepreneur", "Entrepreneur", .business, "an entrepreneur sharing how they build their business",
             themes: [.business, .finance], speaksAs: .i),
        Self("teacher", "Teacher", .educator, "a teacher who explains school and academic subjects simply", themes: [.education]),
        Self("personalTrainer", "Personal trainer", .expert, "a personal trainer who coaches people to train safely and get results", themes: [.fitness]),
        Self("ugcCreator", "UGC creator", .brands, "a UGC creator who films honest, natural videos about products for brands",
             themes: [.shopping, .beauty, .lifestyle], speaksAs: .i),
        Self("nutritionist", "Nutritionist or dietitian", .expert, "a nutritionist who explains food and diet with evidence, without miracle promises",
             themes: [.healthcare, .food, .fitness]),
        Self("beautyCreator", "Beauty creator", .personal, "a beauty creator who tests and recommends makeup, skincare and hair products",
             themes: [.beauty, .shopping]),
        Self("lifeCoach", "Life or relationship coach", .expert, "a life and relationship coach who helps people change habits and relationships",
             themes: [.selfImprovement, .relationships, .wellness]),
        Self("lawyer", "Lawyer", .expert, "a lawyer who explains people's rights in plain words", themes: [.law]),
        Self("realEstateAgent", "Real estate agent", .expert, "a real estate agent who helps people buy, sell and rent homes", themes: [.realEstate]),
        Self("doctor", "Doctor", .expert, "a medical doctor who explains health and symptoms responsibly to patients", themes: [.healthcare]),
        Self("psychologist", "Psychologist or therapist", .expert, "a psychologist or therapist who talks about mental health with care",
             themes: [.wellness, .relationships]),
        Self("comedian", "Comedian", .entertainer, "a comedian who makes sketches and funny takes on everyday life", themes: [.comedy]),
        Self("gamer", "Gamer or streamer", .entertainer, "a gamer and streamer who plays, reviews and talks about games", themes: [.gaming]),
        Self("financeCreator", "Personal finance creator", .educator, "a personal finance creator who teaches people to manage, save and invest money",
             themes: [.finance]),
        Self("makeupArtist", "Makeup artist", .expert, "a professional makeup artist who teaches techniques and books clients", themes: [.beauty]),
        Self("homeCook", "Home cook", .personal, "a home cook who shares easy, real-life recipes", themes: [.food]),
        Self("fitnessCreator", "Fitness creator", .personal, "a fitness creator who shares their training, progress and tips",
             themes: [.fitness, .wellness]),
        Self("vlogger", "Vlogger", .personal, "a vlogger who films their life and talks to camera like a friend", themes: [.lifestyle, .travel]),
        Self("foodReviewer", "Food reviewer", .news, "a food reviewer who tries restaurants and dishes and gives an honest verdict",
             themes: [.food, .travel]),
        Self("courseCreator", "Online course creator", .educator, "an online course creator who teaches a skill and sells a course about it",
             themes: [.education, .business]),
        Self("socialMediaManager", "Social media manager", .brands, "a social media manager who makes videos for a brand or client", themes: [.business]),
        Self("consultant", "Consultant", .expert, "a consultant who shares expertise to win clients for their services", themes: [.business]),
        Self("techReviewer", "Tech reviewer", .news, "a tech reviewer who tests phones, gadgets and apps", themes: [.tech, .shopping]),
        Self("pastor", "Pastor or faith leader", .community, "a pastor or faith leader who shares messages of faith with their community",
             themes: [.faith]),
        Self("musician", "Musician or singer", .entertainer, "a musician or singer who shares their music and their life as an artist",
             themes: [.musicArts]),
        Self("student", "Student", .personal, "a student sharing study routines and student life", themes: [.education, .lifestyle]),
        Self("dentist", "Dentist", .expert, "a dentist who explains oral health and treatments to patients", themes: [.healthcare, .beauty]),
        Self("languageTeacher", "Language teacher", .educator, "a language teacher who helps people learn and speak a new language", themes: [.education]),
        Self("hairStylist", "Hairstylist", .business, "a hairstylist who shows their work and hair care tips to bring clients to the salon",
             themes: [.beauty], speaksAs: .i),
        Self("parentCreator", "Mom or dad creator", .personal, "a parent who shares real family life and parenting tips", themes: [.parenting, .lifestyle]),
        Self("travelCreator", "Travel creator", .personal, "a travel creator who shares places, tips and costs", themes: [.travel]),
        Self("fashionCreator", "Fashion creator", .personal, "a fashion creator who shares outfits, style tips and finds", themes: [.fashion, .shopping]),
        Self("productReviewer", "Product reviewer", .news, "a product reviewer who tests things and says honestly if they are worth it",
             themes: [.shopping]),
        Self("affiliateMarketer", "Affiliate marketer", .brands, "an affiliate who recommends products and earns a commission on sales",
             themes: [.shopping, .business], speaksAs: .i),
        Self("commentator", "Commentator", .news, "a commentator who gives their opinion on what everyone is talking about", themes: [.news, .booksMovies]),
        Self("newsCreator", "News creator or journalist", .news, "a journalist or news creator who explains the news clearly and fairly", themes: [.news]),
        Self("podcaster", "Podcaster", .news, "a podcaster who turns conversations and topics into short clips", themes: [.news, .business, .comedy]),
        Self("esthetician", "Esthetician", .expert, "an esthetician who explains skin treatments and books clients", themes: [.beauty, .healthcare]),
        Self("onlineStoreOwner", "Online store owner", .business, "the owner of an online store showing their products", themes: [.shopping, .business]),
        Self("businessCoach", "Business or career mentor", .expert, "a business and career mentor who helps people grow their work",
             themes: [.business, .productivity]),
        Self("financialAdvisor", "Financial advisor or planner", .expert, "a financial advisor who helps people plan and protect their money",
             themes: [.finance]),
        Self("accountant", "Accountant", .expert, "an accountant who explains taxes and money rules for people and businesses",
             themes: [.finance, .business, .law]),
        Self("faithCreator", "Faith creator", .community, "a believer who shares faith, prayer and encouragement", themes: [.faith]),
        Self("chef", "Chef", .expert, "a professional chef who teaches techniques and shows the kitchen", themes: [.food]),
        Self("baker", "Baker or confectioner", .business, "a baker or confectioner who sells cakes and sweets and shows how they are made",
             themes: [.food], speaksAs: .i),
        Self("restaurantOwner", "Restaurant or café owner", .business, "the owner of a restaurant or café bringing people in", themes: [.food, .business]),
        Self("nurse", "Nurse", .expert, "a nurse who shares health tips and life on the job", themes: [.healthcare]),
        Self("physicalTherapist", "Physical therapist", .expert, "a physical therapist who explains pain, posture and recovery",
             themes: [.healthcare, .fitness]),
        Self("gymOwner", "Gym or studio owner", .business, "the owner of a gym or fitness studio bringing in members", themes: [.fitness, .business]),
        Self("clinic", "Clinic or practice", .business, "a clinic or practice talking to its patients", themes: [.healthcare, .beauty]),
        Self("storyteller", "Storyteller", .entertainer, "a storyteller who tells stories to camera that keep people watching",
             themes: [.comedy, .lifestyle]),
        Self("professionalSharingJob", "Professional sharing my job", .expert, "a professional who shows what their job is really like",
             themes: [.productivity, .lifestyle]),
        Self("corporateProfessional", "Corporate professional", .expert, "a corporate professional sharing career lessons and industry insights",
             themes: [.productivity, .business]),
        Self("executive", "Executive or founder", .expert, "an executive or founder sharing how they lead and build a company", themes: [.business, .tech]),
        Self("marketer", "Marketing professional", .expert, "a marketer who teaches marketing and sales that work", themes: [.business]),
        Self("agencyOwner", "Agency owner", .business, "the owner of an agency winning clients for their services", themes: [.business]),
        Self("freelancer", "Freelancer", .expert, "a freelancer showing their work to win clients", themes: [.business, .productivity]),
        Self("brandTeam", "Brand or company", .brands, "a brand or company speaking to its customers", themes: [.business, .shopping]),
        Self("liveSeller", "Live seller", .business, "a seller who presents and sells products live", themes: [.shopping], speaksAs: .i),
        Self("salesperson", "Salesperson", .expert, "a salesperson who builds trust with buyers before selling", themes: [.business, .shopping]),
        Self("dancer", "Dancer", .entertainer, "a dancer who shares choreography and dance tips", themes: [.musicArts]),
        Self("actor", "Actor or actress", .entertainer, "an actor who plays characters and shares acting life", themes: [.comedy, .booksMovies]),
        Self("reactionCreator", "Reaction creator", .entertainer, "a creator who reacts to videos, trends and news with their own take",
             themes: [.comedy, .booksMovies]),
        Self("filmReviewer", "Film & TV reviewer", .news, "a film and TV reviewer who recommends and analyzes what to watch", themes: [.booksMovies]),
        Self("bookCreator", "Book reviewer", .news, "a book lover who reviews and recommends books", themes: [.booksMovies]),
        Self("writer", "Writer or author", .personal, "a writer or author talking about their books and the writing life", themes: [.booksMovies]),
        Self("trueCrimeCreator", "True crime storyteller", .entertainer, "a true crime storyteller who recounts real cases respectfully",
             themes: [.news, .booksMovies]),
        Self("historyExplainer", "History & facts explainer", .educator, "an explainer of history, facts and curiosities", themes: [.education]),
        Self("scienceCommunicator", "Science communicator", .educator, "a science communicator who makes science easy and fun",
             themes: [.education, .tech]),
        Self("examTutor", "Exam or test prep tutor", .educator, "a tutor who prepares students for exams and tests", themes: [.education]),
        Self("school", "School or course", .business, "a school or course talking to future students", themes: [.education]),
        Self("researcher", "Researcher or academic", .educator, "a researcher who explains their field in plain words", themes: [.education, .healthcare]),
        Self("developer", "Software developer", .expert, "a software developer who teaches coding and tech careers", themes: [.tech, .productivity]),
        Self("aiCreator", "AI creator", .educator, "a creator who shows how to use AI tools in real life and work", themes: [.tech, .business]),
        Self("techRepair", "IT or phone repair tech", .business, "a repair technician who fixes phones and computers and shares tips",
             themes: [.tech], speaksAs: .i),
        Self("pharmacist", "Pharmacist", .expert, "a pharmacist who explains medicines and their safe use", themes: [.healthcare]),
        Self("speechTherapist", "Speech therapist", .expert, "a speech therapist who helps with speech, voice and swallowing",
             themes: [.healthcare, .parenting]),
        Self("veterinarian", "Veterinarian", .expert, "a veterinarian who explains pet health to owners", themes: [.pets, .healthcare]),
        Self("healthJourney", "Health journey creator", .community, "someone sharing their own health journey to help others in the same place",
             themes: [.healthcare, .wellness]),
        Self("holisticTherapist", "Massage or holistic therapist", .expert, "a massage or holistic therapist who talks about relaxation and self-care",
             themes: [.wellness]),
        Self("yogaInstructor", "Yoga or Pilates instructor", .expert, "a yoga or Pilates instructor guiding people to move better",
             themes: [.fitness, .wellness]),
        Self("athlete", "Athlete", .personal, "an athlete sharing training, competitions and life in sport", themes: [.sports, .fitness]),
        Self("sportsCommentator", "Sports commentator", .news, "a sports commentator who analyzes games, teams and players", themes: [.sports]),
        Self("sportsCoach", "Sports coach", .educator, "a sports coach who teaches technique and the game", themes: [.sports, .fitness]),
        Self("barber", "Barber", .business, "a barber showing cuts and grooming tips to bring clients to the shop", themes: [.beauty], speaksAs: .i),
        Self("nailTech", "Nail technician", .business, "a nail technician who shows designs and books clients", themes: [.beauty], speaksAs: .i),
        Self("lashBrowArtist", "Lash or brow artist", .business, "a lash and brow artist who shows results and books clients",
             themes: [.beauty], speaksAs: .i),
        Self("personalStylist", "Personal stylist", .expert, "a personal stylist who helps people dress with confidence", themes: [.fashion]),
        Self("clothingStoreOwner", "Clothing store owner", .business, "the owner of a clothing store showing new pieces and looks",
             themes: [.fashion, .shopping]),
        Self("tattooArtist", "Tattoo artist", .business, "a tattoo artist showing their work and talking with future clients",
             themes: [.artDesign], speaksAs: .i),
        Self("artist", "Artist or illustrator", .personal, "an artist who shows their process and sells their art", themes: [.artDesign]),
        Self("designer", "Graphic designer", .expert, "a graphic designer who teaches design and wins clients", themes: [.artDesign, .business]),
        Self("photographer", "Photographer or videomaker", .expert, "a photographer or videomaker who teaches and books shoots",
             themes: [.artDesign, .events]),
        Self("crafter", "Crafter or maker", .business, "a crafter who makes things by hand and sells them", themes: [.artDesign, .homeDIY], speaksAs: .i),
        Self("architect", "Architect or interior designer", .expert, "an architect or interior designer who shows projects and ideas for homes",
             themes: [.homeDIY, .artDesign, .realEstate]),
        Self("homeCreator", "Home & decor creator", .personal, "a creator sharing home decor, cleaning and organizing ideas", themes: [.homeDIY]),
        Self("organizer", "Cleaning or organizing pro", .business, "a cleaning and organizing professional who shows transformations",
             themes: [.homeDIY], speaksAs: .i),
        Self("builder", "Builder or contractor", .business, "a builder or contractor showing projects and building advice",
             themes: [.trades, .homeDIY], speaksAs: .i),
        Self("tradesperson", "Tradesperson", .expert, "a skilled tradesperson (electrician, plumber, welder…) sharing work and tips",
             themes: [.trades, .homeDIY]),
        Self("engineer", "Engineer", .expert, "an engineer who explains how things are built and work", themes: [.trades, .tech]),
        Self("mechanic", "Mechanic", .business, "a mechanic who explains car problems and maintenance", themes: [.cars], speaksAs: .i),
        Self("carCreator", "Car or motorcycle creator", .news, "a car and motorcycle creator who reviews and talks about vehicles", themes: [.cars]),
        Self("carDealer", "Car dealer", .business, "a car dealer presenting vehicles to buyers", themes: [.cars], speaksAs: .i),
        Self("driver", "Driver or trucker", .personal, "a driver or trucker sharing life on the road", themes: [.cars, .lifestyle]),
        Self("farmer", "Farmer or rancher", .personal, "a farmer or rancher who shows life and work in the countryside", themes: [.agriculture]),
        Self("agronomist", "Agronomist", .expert, "an agronomist who gives practical advice to farmers", themes: [.agriculture]),
        Self("gardener", "Gardener or plant lover", .personal, "a gardener who shares how to grow plants and gardens", themes: [.homeDIY, .agriculture]),
        Self("petCreator", "Pet creator", .personal, "a pet owner who shares life with their animals and pet tips", themes: [.pets]),
        Self("dogTrainer", "Dog trainer", .expert, "a dog trainer who teaches owners to understand and train their dogs", themes: [.pets]),
        Self("petBusiness", "Pet shop or groomer", .business, "a pet shop or groomer talking to pet owners", themes: [.pets]),
        Self("travelAgent", "Travel agent or tour guide", .business, "a travel agent or guide who sells and plans trips", themes: [.travel], speaksAs: .i),
        Self("host", "Hotel or rental host", .business, "a hotel or vacation rental host showing their place to guests", themes: [.travel, .realEstate]),
        Self("expat", "Expat or immigrant", .personal, "someone living in another country who shares that life and how to do it",
             themes: [.travel, .lifestyle]),
        Self("relationshipCreator", "Relationship or couple creator", .personal, "a creator who talks about love, dating and couple life",
             themes: [.relationships]),
        Self("church", "Church or ministry", .community, "a church or ministry speaking to its members and visitors", themes: [.faith], speaksAs: .we),
        Self("spiritualGuide", "Spiritual or astrology guide", .expert, "a spiritual guide or astrologer who shares reflections and readings",
             themes: [.faith, .wellness]),
        Self("motivationalSpeaker", "Speaker or motivator", .expert, "a speaker who shares lessons that motivate people to act",
             themes: [.selfImprovement, .business]),
        Self("eventPlanner", "Event or wedding planner", .business, "an event and wedding planner showing events and planning tips",
             themes: [.events], speaksAs: .i),
        Self("nonprofit", "Nonprofit or NGO", .community, "a nonprofit sharing its cause and how people can help", themes: [.causes], speaksAs: .we),
        Self("activist", "Activist or advocate", .community, "an advocate raising awareness of a cause", themes: [.causes, .news]),
        Self("publicServant", "Public servant", .expert, "a public servant who explains public services and safety to citizens", themes: [.news, .law]),
        Self("recruiter", "Recruiter or HR pro", .expert, "a recruiter or HR professional who helps people get hired", themes: [.productivity]),
        Self("insuranceAgent", "Insurance agent", .expert, "an insurance agent who explains protection plans simply", themes: [.finance]),
        Self("investor", "Investor", .expert, "an investor sharing how they invest, with no promises of returns", themes: [.finance]),
        Self("creatorOver50", "Creator over 50", .personal, "a creator over 50 sharing life, style and experience",
             themes: [.lifestyle, .fashion, .wellness]),
        Self("beginner", "Just starting out", .personal, "someone just starting to make videos, still finding their topic", themes: [.lifestyle]),
    ]

    private static let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
}
