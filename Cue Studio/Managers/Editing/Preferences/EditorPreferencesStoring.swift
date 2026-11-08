//
//  EditorPreferencesStoring.swift
//  Cue Studio
//

import Foundation

/// How the creator left Quick edit's own switches, kept between edits on this device (any take).
@MainActor
protocol EditorPreferencesStoring: AnyObject {
    /// Voice-over's "Show script": the take's script over the preview while a narration records (on until turned off).
    var showsNarrationScript: Bool { get set }
    /// How fast that script scrolls, on `PrompterSettings.speed`'s scale; nil reads at the prompter's speed.
    var narrationScriptSpeed: Double? { get set }
    /// When the Low Power Mode notice last showed (`LowPowerNotice`: once a day).
    var lowPowerNoticeShownAt: Date? { get set }
    /// The track the timeline showed under the video when the take was last edited (`TimelineTrackChoice.current`).
    func timelineLane(forTake id: UUID) -> TimelineLane?
    func setTimelineLane(_ lane: TimelineLane, forTake id: UUID)
    /// Whether the kit for new videos already went on this take once (`BrandViewModel.wearNewVideoKit`): undone, it isn't put
    /// on again the next time the take opens.
    func newVideoKitOffered(forTake id: UUID) -> Bool
    func markNewVideoKitOffered(forTake id: UUID)
}
