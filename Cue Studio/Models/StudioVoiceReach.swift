//
//  StudioVoiceReach.swift
//  Cue Studio
//

import Foundation

/// Which recordings of an edit Studio Voice treats. The take is always one of them; in a montage, the other takes and videos
/// are treated too unless the creator leaves one out (a video with music in it, a clip filmed somewhere quiet). Music,
/// voice-overs and the sound of videos laid over the take are never treated: they aren't speech recorded for the video.
nonisolated enum StudioVoiceReach: Codable, Hashable, Sendable {
    /// Only the take: edits saved before montages could be treated, so they sound as they did.
    case takeOnly
    /// The take and every other recording of the montage but these (`ClipSource.id`).
    case allRecordings(except: Set<UUID>)

    /// What new edits get.
    static let standard = StudioVoiceReach.allRecordings(except: [])

    /// Whether the recording `sourceID` is treated (nil: the take, always).
    func treats(_ sourceID: UUID?) -> Bool {
        guard let sourceID else { return true }
        switch self {
        case .takeOnly: return false
        case .allRecordings(let except): return !except.contains(sourceID)
        }
    }

    /// The same reach with `sourceID` treated or left out.
    func setting(_ sourceID: UUID, treated: Bool, among sources: [UUID]) -> StudioVoiceReach {
        var left: Set<UUID> = switch self {
        case .takeOnly: Set(sources)
        case .allRecordings(let except): except
        }
        if treated { left.remove(sourceID) } else { left.insert(sourceID) }
        return .allRecordings(except: left)
    }
}
