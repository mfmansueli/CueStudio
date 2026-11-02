#if DEBUG
import Foundation

/// An evaluation ablation, not a replacement for the creator's saved profile.
nonisolated enum PCCDeliveryVoice {
    static func prepare(_ request: ScriptRequest, on route: AIModelRoute) -> ScriptRequest {
        guard route == .privateCloud, request.durationPolicy == .informative,
              var voice = request.voice else { return request }
        // Keep the resolved default before removing the role that may have supplied it.
        voice.speaksAs = voice.resolvedSpeaksAs
        voice.role = nil
        voice.customRole = nil
        voice.credential = nil
        voice.topics = []
        voice.audienceGroup = nil
        voice.audienceNote = nil
        voice.watchReasons = []
        voice.contentGoals = []
        voice.openings = []
        voice.endings = []
        voice.formats = []
        voice.customFormats = []
        voice.reach.platforms = []
        voice.reach.length = nil
        // Sounds, delivery, humor, vocabulary, knowledge level, avoid rules, typed style tags,
        // catchphrases, the measured fingerprint and the proof (examples, excerpts, approved scripts) stay.
        var prepared = request
        prepared.voice = voice
        return prepared
    }
}
#endif
