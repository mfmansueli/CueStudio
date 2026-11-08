//
//  AutoEditRecord.swift
//  Cue Studio
//

import Foundation

/// What the last Auto edit did (E5, plan §14), kept with the edit so each step can be turned off later on its own, without
/// touching anything else: the pauses, hesitations and tries it took out (put back by id), whether it made the captions (turned
/// off they hide, the lines stay), and the phrase zooms it added (taken away by id, the creator's own stay).
nonisolated struct AutoEditRecord: Codable, Hashable, Sendable {
    /// Clean up's suggestions the pass removed.
    var removedSuggestions: [UUID] = []
    /// The seconds the removals took out of the video.
    var removedSeconds: TimeInterval = 0
    /// The pass made the captions (there were none).
    var madeCaptions = false
    /// The phrase zooms the pass added.
    var zoomIDs: [UUID] = []
    /// The steps that ran to the end (a step picked whose listening failed didn't).
    var ranSteps: Set<AutoEditStep> = []
    /// The steps turned off since.
    var offSteps: Set<AutoEditStep> = []

    init(removedSuggestions: [UUID] = [], removedSeconds: TimeInterval = 0, madeCaptions: Bool = false, zoomIDs: [UUID] = []) {
        self.removedSuggestions = removedSuggestions
        self.removedSeconds = removedSeconds
        self.madeCaptions = madeCaptions
        self.zoomIDs = zoomIDs
    }

    private enum CodingKeys: String, CodingKey {
        case removedSuggestions, removedSeconds, madeCaptions, zoomIDs, ranSteps, offSteps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        removedSuggestions = (try? container.decodeIfPresent([UUID].self, forKey: .removedSuggestions)) ?? []
        removedSeconds = (try? container.decodeIfPresent(TimeInterval.self, forKey: .removedSeconds)) ?? 0
        madeCaptions = (try? container.decodeIfPresent(Bool.self, forKey: .madeCaptions)) ?? false
        zoomIDs = (try? container.decodeIfPresent([UUID].self, forKey: .zoomIDs)) ?? []
        // A step a newer Cue added is left out rather than failing the edit.
        offSteps = Self.steps(in: container, .offSteps)
        ranSteps = Self.steps(in: container, .ranSteps)
    }

    private static func steps(in container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Set<AutoEditStep> {
        let names = (try? container.decodeIfPresent([String].self, forKey: key)) ?? []
        return Set(names.compactMap(AutoEditStep.init(rawValue:)))
    }

    /// Whether the pass did anything for `step` that is still on.
    func isOn(_ step: AutoEditStep) -> Bool {
        guard !offSteps.contains(step) else { return false }
        return switch step {
        case .speech: !removedSuggestions.isEmpty
        case .captions: madeCaptions
        case .zoom: !zoomIDs.isEmpty
        }
    }
}
