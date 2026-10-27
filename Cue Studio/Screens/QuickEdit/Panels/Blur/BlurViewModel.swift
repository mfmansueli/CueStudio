//
//  BlurViewModel.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import os

/// Blur area (`EditorPart`): faces, plates, names on a screen hidden with a heavy blur, coarse pixels or a solid bar, each on
/// its footage's own seconds (`BlurRegion`). A tap on a face found in the frame makes an area that follows that face at once
/// (through the motion analysis Cue already keeps, else Vision's tracker); a drawn area follows what's inside it when asked.
/// Where Cue couldn't confirm the area covers its subject, the stretch is marked on the timeline and in the panel, with a way
/// there, a way to follow again from a corrected spot, to end the area, or to say it's right: nothing ever says covered while
/// one is left. What it keeps is its panel's state; the areas are in the edit, and every change is an undo step.
///
/// Each part of the work is in its own extension (`+Adding`, `+Following`, `+Editing`, `+Preview`).
@MainActor
@Observable
final class BlurViewModel: EditorPart {
    /// Choosing what to hide (`BlurPicking`); nil once an area is made or the panel closes.
    var picking: BlurPicking?
    /// The area being followed and how far, 0 to 1; nil while nothing is.
    var following: (id: UUID, progress: Double)?
    /// Counts the times following ended with the area's card in view: the card's sign jumps (its confirmation, no toast).
    var followingEnded = 0
    /// ◐: the preview without any Blur area.
    var comparesOriginal = false {
        didSet {
            guard comparesOriginal != oldValue else { return }
            session.showPlayedEdit()
        }
    }
    /// Upright sizes of the footage the handles are drawn on, by file.
    var uprightSizes: [URL: CGSize] = [:]
    /// What a new area looks like: the look the creator last gave one in this video (`BlurLook.initial` until then), kept with
    /// its edit.
    var lastLook: BlurLook { edit.blurLook ?? .initial }
    /// Areas waiting to be followed after the one following now (every face but the largest).
    @ObservationIgnored var followQueue: [UUID] = []
    /// How each recording lands on the frame, worked out once per setting (`+Preview`).
    @ObservationIgnored var placements: [String: FramePlacement] = [:]
    /// Tells the running follow to stop where it is, keeping what it followed (read on its own thread).
    @ObservationIgnored let stopFlag = OSAllocatedUnfairLock(initialState: false)

    let session: EditorSession
    /// Follows a drawn area (or a face the analysis doesn't reach) through its footage.
    let tracker: ObjectTracking
    /// Finds the faces offered in the first step where the motion analysis hasn't reached.
    let faces: FaceFinding

    init(session: EditorSession, tracker: ObjectTracking, faces: FaceFinding = FaceFinder()) {
        self.session = session
        self.tracker = tracker
        self.faces = faces
    }

    /// The edit changed: an area being followed that's gone stops, and a comparison is no longer of what shows.
    func editChanged() {
        if let following, !edit.blurRegions.contains(where: { $0.id == following.id }) { stopCurrentFollowing() }
        followQueue.removeAll { id in !edit.blurRegions.contains { $0.id == id } }
        if comparesOriginal { comparesOriginal = false }
    }

    /// The panel changed to `next`: leaving Blur area ends choosing and comparing (following goes on).
    func panelChanged(to next: EditorPanel?) {
        guard next != .blur else { return }
        picking = nil
        comparesOriginal = false
    }

    /// `edit` as the preview plays it while ◐ is on: without any Blur area.
    func withoutComparedBlur(_ edit: TakeEdit) -> TakeEdit {
        guard comparesOriginal, !edit.blurRegions.isEmpty else { return edit }
        var shown = edit
        shown.blurRegions = []
        return shown
    }

    /// ◐ in Blur area: the picture as it was, without what's hidden.
    var blurCompare: PanelCompare {
        PanelCompare(
            isOn: comparesOriginal, isEnabled: !edit.blurRegions.isEmpty, hint: String(localized: "Shows the video without its Blur areas"),
            identifier: "edit.compare.blur"
        ) { [weak self] isOn in
            guard let self, !isOn || !edit.blurRegions.isEmpty else { return }
            comparesOriginal = isOn
        }
    }

    /// The file of a footage.
    func url(of target: BlurTarget) -> URL? {
        if let id = target.mediaID { return edit.media.first { $0.id == id }.map { EditMediaFiles.url(for: $0.fileName) } }
        guard let id = target.recordingID else { return videoURL }
        return edit.sources.first { $0.id == id }.map { EditMediaFiles.url(for: $0.fileName) }
    }
}
