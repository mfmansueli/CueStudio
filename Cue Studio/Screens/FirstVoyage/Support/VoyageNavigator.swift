//
//  VoyageNavigator.swift
//  Cue Studio
//

import Foundation

/// Where each step of the first voyage starts: Find inspiration to write, the teleprompter to practice (Studio) or to record
/// (Selfie), the review of the take to pick, polish (the editor) or share. The script is the one changed last; the take is the
/// latest, or the best take of its script once there is one.
@MainActor
struct VoyageNavigator {
    let library: ScriptLibraryService
    let takes: TakeLibraryService
    let presentation: PresentationService

    func start(_ step: VoyageStep) {
        switch step {
        case .write:
            // Ideas from the creator's topics, the way in that asks least ("An idea is enough"); a brief used there goes into the dock on
            // Scripts, so Scripts is where it opens.
            presentation.select(.scripts)
            presentation.present(.ideas)
        case .practice:
            presentation.openPrompter(scriptID: latestScript?.id, mode: .studio)
        case .record:
            presentation.openPrompter(scriptID: latestScript?.id, mode: .selfie)
        case .pick:
            guard let take = latestTake else { return }
            let siblings = takes.takes.filter { $0.scriptID == take.scriptID }
            presentation.openReview(of: take, then: siblings.count > 1 && !siblings.contains(where: \.isBest) ? .pickBest : nil)
        case .polish:
            guard let take = videoTake else { return }
            presentation.openReview(of: take, then: .edit)
        case .share:
            guard let take = videoTake else { return }
            presentation.openReview(of: take, then: .share)
        }
    }

    var latestScript: Script? {
        library.scripts.max { $0.updatedAt < $1.updatedAt }
    }

    var latestTake: Take? {
        takes.takes.max { $0.recordedAt < $1.recordedAt }
    }

    /// The take that becomes the video: the best take of the latest take's script, or the latest take.
    var videoTake: Take? {
        guard let latest = latestTake else { return nil }
        return takes.takes.first { $0.scriptID == latest.scriptID && $0.isBest } ?? latest
    }
}
