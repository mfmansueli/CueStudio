//
//  QuickEditViewModel+Background.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// Background: blur the creator's background, or put a color or a photo behind them, found by
/// Vision on the iPhone or by a green or blue screen (a chroma key). It belongs to a recording: the
/// one under the playhead (the take, or another take or video of a montage), on every section of
/// it, unless a clip sets its own (opened from a picked clip, `QuickEditViewModel+ClipLook`). Every
/// change is an undo step; a slider is one. The recording itself never changes.
extension QuickEditViewModel {
    /// The recording under the playhead: nil for the take.
    var backgroundSourceID: UUID? {
        let segments = edit.timeline.segments
        guard !segments.isEmpty else { return nil }
        return segments[edit.timeline.segmentIndex(atEdited: player.currentTime)].sourceID
    }

    /// The settings the panel shows, kept even while Original: the picked clip's own, or its
    /// recording's where the clip sets none, when Background is changing a clip; else the recording's
    /// under the playhead.
    var currentBackground: BackgroundEffect {
        if let clip = lookClip { return clip.look?.background ?? inheritedBackground(of: clip) }
        let id = backgroundSourceID
        return edit.backgrounds.first { $0.sourceID == id }?.effect ?? BackgroundEffect()
    }

    /// What a clip's recording does to its background, which the clip shows through until it sets
    /// its own.
    private func inheritedBackground(of clip: EditSegment) -> BackgroundEffect {
        edit.backgrounds.first { $0.sourceID == clip.sourceID }?.effect ?? BackgroundEffect()
    }

    /// The picked clip sets its own background.
    var clipOverridesBackground: Bool {
        lookClip?.look?.background != nil
    }

    /// The panel's subtitle: what it changes, and what is behind the creator now ("Clip 2 of 3 · Blur behind you").
    var backgroundSubtitle: String {
        let scope = lookClip == nil ? String(localized: "Whole video") : clipScope
        return String(localized: "\(scope) · \(Self.backgroundSummary(of: currentBackground))")
    }

    /// What is behind the creator, in a few words: Original, or the background and how it's cut out.
    static func backgroundSummary(of effect: BackgroundEffect) -> String {
        switch (effect.style, effect.cutout) {
        case (.original, _): String(localized: "As recorded")
        case (.image, _) where effect.imageFileName == nil: String(localized: "No photo chosen yet")
        case (.blur, .person): String(localized: "Blur behind you")
        case (.color, .person): String(localized: "Color behind you")
        case (.image, .person): String(localized: "Image behind you")
        case (.blur, .colorKey): String(localized: "Blur on the green or blue screen")
        case (.color, .colorKey): String(localized: "Color on the green or blue screen")
        case (.image, .colorKey): String(localized: "Image on the green or blue screen")
        }
    }

    /// The rule of the panel's scope, when there is one to tell: a clip with its own background (Reset gives it the take's again), a clip
    /// showing the take's, or a take with clips that keep their own.
    var backgroundScopeNote: String? {
        if lookClip != nil {
            return clipOverridesBackground
                ? String(localized: "This clip has its own background. Reset gives it the whole video's again.")
                : String(localized: "Shows the whole video's background. A change here is for this clip only.")
        }
        return someClipKeepsItsOwn(for: .background) ? String(localized: "Clips with their own background keep it.") : nil
    }

    /// The green or blue screen's Tolerance, Edge or Spill was moved from where it starts.
    var backgroundKeyIsAdjusted: Bool {
        let key = currentBackground.key, start = ChromaKey.green
        return abs(key.tolerance - start.tolerance) > 0.001 || abs(key.softness - start.softness) > 0.001 || abs(key.spill - start.spill) > 0.001
    }

    /// The clip's recording's background again.
    func resetClipBackground() {
        updateClipLook { $0.background = nil }
    }

    /// Asks once whether this iPhone can find people in video.
    func checkBackgroundSupport() async {
        guard canFindPeople == nil else { return }
        canFindPeople = await BackgroundSupport.canFindPeople()
    }

    /// Changes the background of the recording under the playhead (one undo step, or part of the
    /// gesture's).
    func updateBackground(_ update: (inout BackgroundEffect) -> Void) {
        let id = backgroundSourceID
        var effect = currentBackground
        update(&effect)
        effect.blur = min(max(effect.blur, BackgroundEffect.blurRange.lowerBound), BackgroundEffect.blurRange.upperBound)
        effect.key.tolerance = min(max(effect.key.tolerance, 0), 1)
        effect.key.softness = min(max(effect.key.softness, 0), 1)
        effect.key.spill = min(max(effect.key.spill, 0), 1)
        if let clip = lookClip {
            // The clip's own; one that comes to be what its recording has goes, so it inherits again.
            updateClipLook { $0.background = effect == inheritedBackground(of: clip) ? nil : effect }
            return
        }
        var changed = edit
        changed.setBackground(effect, for: id)
        let backgrounds = changed.backgrounds
        change { $0.backgrounds = backgrounds }
    }

    func setBackgroundStyle(_ style: BackgroundStyle) {
        updateBackground { $0.style = style }
    }

    func setBackgroundCutout(_ cutout: BackgroundCutout) {
        updateBackground { $0.cutout = cutout }
    }

    /// The key color from a picked color (sRGB).
    func setKeyColor(red: Double, green: Double, blue: Double) {
        updateBackground { $0.key = $0.key.keying(red: red, green: green, blue: blue) }
    }

    /// Copies the picked photo in and puts it behind the creator.
    func importBackgroundImage(_ item: PhotosPickerItem) async {
        guard isReady, !isImportingBackground else { return }
        isImportingBackground = true
        defer { isImportingBackground = false }
        do {
            let imported = try await mediaImporter.importMedia(item)
            guard imported.kind == .photo, !isClosed else {
                EditMediaFiles.remove([imported.fileName])
                if !isClosed { toast.show(String(localized: "Can't add this file")) }
                return
            }
            setBackgroundImage(imported.fileName)
        } catch {
            noteFailure(error, "importBackground")
            toast.show(error.localizedDescription)
        }
    }

    /// Puts a photo already in the edit's media behind the creator.
    func setBackgroundImage(_ fileName: String) {
        importedFiles.insert(fileName)
        updateBackground { effect in
            effect.imageFileName = fileName
            effect.style = .image
        }
    }
}
