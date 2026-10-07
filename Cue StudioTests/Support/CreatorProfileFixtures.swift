//
//  CreatorProfileFixtures.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Profiles as older builds saved them, written out the way their encoders did (the keys of `CreatorProfile` before My Cue Voice for Apple
/// Intelligence): what a creator updating the app has on the iPhone. Nothing here has a key of the v2 fields.
enum CreatorProfileFixtures {
    /// v1: one tone, no voice layers.
    static let v1 = """
    {"name":"Maya Reyes","handle":"mayamakes","niches":["wellness"],"phrases":["Hey fam"],
     "tone":"energetic","defaultPlatform":"reels","monetizationGoals":false}
    """

    /// v29: the layers existed but the question bank (`style`, `avoid`, `reach`, `audienceLevel`) didn't, and swearing was a field of its own.
    static let v29 = """
    {"name":"Noah","handle":"noahmakes","niches":["tech","productivity"],"customTopics":["Chess"],"phrases":["Okay, real talk."],
     "role":"educator","voiceApproved":false,"sounds":["casual","educational"],"vocabulary":"technical",
     "styles":["storytelling","conversational"],"usesVoiceInAI":true,"defaultPlatform":"tiktok","monetizationGoals":true,
     "confirmedVoiceSteps":["audience","tone"],"openings":["Question"],"endings":["Follow for more"],"formats":["tutorial","list"],
     "swearing":"mild","examples":[],"customTags":["Talking head"],"declinedVoiceItems":["swearing"]}
    """

    /// v30: everything of the question bank, as `34964a1` writes it.
    static let v30 = """
    {"name":"Maya","handle":"maya.yoga","niches":["fitness"],"customTopics":[],"phrases":["Breathe in."],"role":"expert",
     "voiceApproved":true,"sounds":["warmCalm","educational"],"vocabulary":"simple","styles":["shortSentences","conversational"],
     "usesVoiceInAI":true,"defaultPlatform":"tiktok","monetizationGoals":true,"confirmedVoiceSteps":["audience","tone"],
     "unverifiedVoiceSteps":[],"openings":["Question"],"endings":["Save this"],"formats":["tutorial"],
     "style":{"energy":"calm","sentences":"mixed","words":"plain","swearing":"never"},"avoid":["Medical claims","Hype words"],
     "avoidNone":false,"reach":{"platforms":["tiktok"],"length":"thirtyToSixty","humor":"little"},"audienceLevel":"new","approvals":4,
     "examples":[{"id":"6F1D8C58-1B5C-4C3D-9E0A-2F7B5E9A1C11","text":"Okay, real talk. Mornings are hard.","source":"Pasted","addedAt":781000000}],
     "customTags":["Talking head"],"declinedVoiceItems":[]}
    """

    static func decode(_ json: String) throws -> CreatorProfile {
        try JSONDecoder().decode(CreatorProfile.self, from: Data(json.utf8))
    }
}
