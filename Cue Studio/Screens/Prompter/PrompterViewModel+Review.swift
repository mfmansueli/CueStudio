//
//  PrompterViewModel+Review.swift
//  Cue Studio
//

import Foundation

extension PrompterViewModel {
    func openLastTake() {
        guard let lastTake, !isRecording else { return }
        pause()
        reviewingTake = lastTake
    }

    /// 04 · F3: a stop that leaves two takes or more in the take's video (its script, the network it was recorded for) and no ★ opens
    /// "Pick your best take" first; a single take (or a freestyle one, which has no siblings) goes straight to its review.
    func shouldPickBest(after take: Take) -> Bool {
        guard !take.isFreestyle else { return false }
        let siblings = takes.takes(in: take.videoKey)
        return siblings.count > 1 && !siblings.contains(where: \.isBest)
    }

    /// The video this session's takes join: the script's takes for the network this session records for (`platform`, which every new
    /// take is filed with). Nil in Freestyle, where every take is a video of its own.
    var recordingVideo: TakeVideoKey? {
        scriptID.map { TakeVideoKey.script($0, platform) }
    }
}
