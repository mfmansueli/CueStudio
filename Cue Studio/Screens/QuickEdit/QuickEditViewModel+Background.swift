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
/// it. Every change is an undo step; a slider is one. The recording itself never changes.
extension QuickEditViewModel {
    /// The recording under the playhead: nil for the take.
    var backgroundSourceID: UUID? {
        let segments = edit.timeline.segments
        guard !segments.isEmpty else { return nil }
        return segments[edit.timeline.segmentIndex(atEdited: player.currentTime)].sourceID
    }

    /// What the effect applies to: "This take", or the other recording's name.
    var backgroundTargetTitle: String {
        guard let id = backgroundSourceID, let source = edit.sources.first(where: { $0.id == id }) else {
            return String(localized: "This take")
        }
        return source.title
    }

    /// The recording's settings, kept even while Original.
    var currentBackground: BackgroundEffect {
        let id = backgroundSourceID
        return edit.backgrounds.first { $0.sourceID == id }?.effect ?? BackgroundEffect()
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
                if !isClosed { toast.show(String(localized: "This photo or video can't be added")) }
                return
            }
            setBackgroundImage(imported.fileName)
        } catch {
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
