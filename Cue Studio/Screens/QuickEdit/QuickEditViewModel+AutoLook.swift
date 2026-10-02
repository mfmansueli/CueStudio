//
//  QuickEditViewModel+AutoLook.swift
//  Cue Studio
//

import Foundation

/// Adjust › Auto: a correction measured on the clip (`AutoAdjustAnalyzer`, Core Image's analysis of
/// a few frames), kept as numbers (`AutoCorrection`) so it plays the same everywhere. It is a step
/// of its own, before the dials: the creator's Adjust values stay as they are on top of it, and
/// its intensity, "Compare" and Reset work without measuring again. Opened from the main toolbar
/// it measures the take's own recording; opened from a clip, that clip.
///
/// A measurement belongs to what was picked when it started: finishing after the picked clip
/// changed, the panel closed or the editor was left, it is dropped, never applied to another clip.
extension QuickEditViewModel {
    enum AutoAdjustState: Equatable {
        case idle, analyzing
    }

    /// What a measurement looks at and is for.
    struct AutoTarget: Equatable {
        /// The clip it is for; nil for the whole take.
        let clipID: UUID?
        let url: URL
        let spans: [TimeSpan]
    }

    // MARK: - What the panel shows

    /// How much of Auto shows, 0 to 1: the clip's (or the take's, where the clip sets none) when
    /// Adjust is changing a clip, else the take's.
    var autoAmount: Double { effectiveLook.autoAmount }

    /// Something measured is playing here.
    var hasAuto: Bool { effectiveLook.auto != nil }

    /// The picked clip sets its own Auto (or turns the take's down).
    var clipOverridesAuto: Bool { lookClip?.look?.overridesAuto ?? false }

    /// Auto has something to reset: a correction for the take, one the clip set for a clip.
    var canResetAuto: Bool {
        lookClip != nil ? clipOverridesAuto : edit.autoCorrection != nil
    }

    // MARK: - Measuring

    /// Where Auto looks for the scope Adjust has now; nil when there is nothing to look at.
    var autoTarget: AutoTarget? {
        if let clip = lookClip {
            guard let url = recordingURL(of: clip.sourceID) else { return nil }
            return AutoTarget(clipID: clip.id, url: url, spans: [clip.span])
        }
        let spans = edit.timeline.segments.filter { $0.sourceID == nil }.map(\.span)
        return spans.isEmpty ? nil : AutoTarget(clipID: nil, url: videoURL, spans: spans)
    }

    /// Measures the picture and applies the result. Does nothing while a measurement runs.
    func autoAdjust() {
        guard isReady, !isClosed, autoState != .analyzing else { return }
        guard let target = autoTarget else {
            toast.show(String(localized: "Couldn’t measure the picture — it stays as it is"))
            return
        }
        comparesPicture = false
        let request = UUID()
        autoRequest = request
        autoState = .analyzing
        autoTask = Task { [editing] in
            do {
                let found = try await editing.autoCorrection(forVideoAt: target.url, spans: target.spans)
                finishAuto(request, target: target, found: found)
            } catch is CancellationError {
                if autoRequest == request {
                    autoRequest = nil
                    autoState = .idle
                }
            } catch {
                finishAuto(request, target: target, found: nil)
            }
        }
    }

    /// Stops measuring; whatever it finds later is dropped.
    func cancelAuto() {
        autoTask?.cancel()
        autoTask = nil
        autoRequest = nil
        if autoState != .idle { autoState = .idle }
    }

    private func finishAuto(_ request: UUID, target: AutoTarget, found: AutoCorrection?) {
        guard autoRequest == request, !isClosed else { return }
        autoRequest = nil
        autoTask = nil
        autoState = .idle
        // The picked clip (or the whole take) is still what it was measured for.
        guard panel == .adjust, target.clipID == lookClip?.id else { return }
        guard let found else {
            toast.show(String(localized: "Couldn’t measure the picture — it stays as it is"))
            return
        }
        let correction = found.limited()
        guard !correction.isNeutral else {
            toast.show(String(localized: "Already balanced — nothing to correct"))
            return
        }
        if lookClip != nil {
            updateClipLook(key: "auto") {
                $0.auto = correction
                $0.autoAmount = 1
            }
        } else {
            changeLook(key: "auto") {
                $0.autoCorrection = correction
                $0.autoAmount = 1
            }
        }
        toast.show(String(localized: "Auto applied — adjust it below"))
    }

    // MARK: - Intensity, reset, compare

    /// How much of Auto shows, 0 to 100.
    func setAutoAmount(_ percent: Double) {
        let amount = min(max(percent.rounded(), 0), 100) / 100
        if lookClip != nil {
            updateClipLook(key: "auto.amount") { $0.autoAmount = amount }
        } else {
            changeLook(key: "auto.amount") { $0.autoAmount = amount }
        }
    }

    /// Auto back to nothing for the take; for a clip, the take's Auto again.
    func resetAuto() {
        cancelAuto()
        if lookClip != nil {
            updateClipLook { $0.removeAuto() }
        } else {
            changeLook {
                $0.autoCorrection = nil
                $0.autoAmount = 1
            }
        }
    }

    /// "Compare": the preview shows the picture as recorded, or comes back to the edit.
    func togglePictureComparison() {
        guard comparesPicture || edit.hasPictureLook else { return }
        comparesPicture.toggle()
    }

    // MARK: - Recordings

    /// The file a recording is read from: the take's own (nil), or a montage's other recording.
    func recordingURL(of sourceID: UUID?) -> URL? {
        guard let sourceID else { return videoURL }
        return edit.sources.first { $0.id == sourceID }.map { EditMediaFiles.url(for: $0.fileName) }
    }
}
