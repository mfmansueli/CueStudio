//
//  LookViewModel+SafeGuide.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The safe zone guide (owner, decision B, 07/11/2026): where an app's buttons cover the video, drawn over the preview only, never
/// in the file. Turned on in Aspect ratio › Safe zones (the creator's way of working, kept for every video, no undo step); it opens
/// on the script's platform, or the generic guide without one, and the platform is switched in the panel or on the guide's label.
/// The switch is this video's (`TakeEdit.safeGuide`) and one undo step, because the captions move with it: they keep to the
/// guide's clear area, in the preview and in the file alike.
extension LookViewModel {
    /// The guides this frame offers: the platforms measured on it, then Generic.
    var safeGuideOptions: [SafeGuideChoice] {
        CaptionSafeArea.zones.options(for: edit.aspect)
    }

    /// The guide the video shows and its captions keep to.
    var safeGuide: SafeGuideChoice {
        CaptionSafeArea.guide(of: edit, for: take)
    }

    /// The guide the script's platform suggests on this frame (Generic without one measured here).
    var suggestedSafeGuide: SafeGuideChoice {
        CaptionSafeArea.zones.suggestion(scriptPlatform: take.platform, aspect: edit.aspect)
    }

    /// Under the guides in the panel: where the one shown came from.
    var safeGuideNote: String {
        switch suggestedSafeGuide {
        case .platform(let platform):
            String(localized: "Suggested by your script: \(platform.label)", comment: "Video editor, Aspect ratio › Safe zones: e.g. TikTok")
        case .generic:
            String(localized: "No app on your script for this format: generic guide", comment: "Video editor, Aspect ratio › Safe zones")
        }
    }

    /// The guide's clear area on a preview of `size`, in its points.
    func safeGuideRect(in size: CGSize) -> CGRect {
        let unit = CaptionSafeArea.zones.margins(of: safeGuide, aspect: edit.aspect).unitContentRect
        return CGRect(x: unit.minX * size.width, y: unit.minY * size.height, width: unit.width * size.width, height: unit.height * size.height)
    }

    /// Shows or hides the guide, for every video (no undo step: nothing in the video changes).
    func setShowsSafeGuide(_ shows: Bool) {
        guard shows != showsSafeGuide else { return }
        showsSafeGuide = shows
        announce(shows ? String(localized: "Safe zone: \(safeGuide.approximateLabel)") : String(localized: "Safe zone hidden"))
    }

    /// Shows another app's guide on this video, one undo step: the captions take its clear area with it, so where they sit in the
    /// preview is where they sit in the file. The guide shows, if it was hidden.
    func pickSafeGuide(_ choice: SafeGuideChoice) {
        showsSafeGuide = true
        guard choice != safeGuide, safeGuideOptions.contains(choice) else { return }
        let take = take
        changeEdit { edit in
            edit.safeGuide = choice
            edit.captionCollection?.safeMargins = CaptionSafeArea.margins(for: take, aspect: edit.aspect, pick: choice)
        }
        announce(String(localized: "Safe zone: \(choice.approximateLabel)"))
    }
}
