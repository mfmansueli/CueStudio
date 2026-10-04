//
//  TakePipeline.swift
//  Cue Studio
//

import Foundation

/// The header of the Takes tab: how many videos are at each stage, and what to do next. Pure.
nonisolated struct TakePipeline: Equatable, Sendable {
    /// Where the next step is, and the video it is for.
    struct Next: Equatable, Sendable {
        let stage: TakeStage
        let video: TakeVideo
    }

    let counts: [TakeStage: Int]
    /// The first stage with a video waiting (pick, then edit, then ready), with the **oldest** video
    /// in it: the one that has waited longest. Nil when every video is shared (or there are none).
    let next: Next?

    /// `videos` are newest first, as `TakeLibraryFilter.videos` returns them.
    init(videos: [TakeVideo]) {
        var counts: [TakeStage: Int] = [:]
        for stage in TakeStage.allCases { counts[stage] = videos.filter { $0.stage == stage }.count }
        self.counts = counts
        next = TakeStage.allCases.lazy
            .filter { $0.nextVerb != nil }
            .compactMap { stage in videos.last(where: { $0.stage == stage }).map { Next(stage: stage, video: $0) } }
            .first
    }

    func count(of stage: TakeStage) -> Int { counts[stage] ?? 0 }
}
