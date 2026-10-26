//
//  QuickEditViewModel+Blur.swift
//  Cue Studio
//

import Foundation

/// Blur areas on the timeline: a bar for every showing of each area (a clip's copies show it again), what's left unchecked
/// hatched on it, trimmed by its ends (it stays on what it covers, so it isn't dragged along).
extension QuickEditViewModel {
    /// Every showing of every area, in order.
    var blurInstances: [BlurInstance] {
        let timeline = edit.timeline
        return edit.blurRegions.flatMap { region -> [BlurInstance] in
            let spans = edit.editedSpans(of: region, in: timeline)
            // Where its unchecked stretches show, in edited seconds.
            let warnings = region.openUnchecked.flatMap { stretch -> [TimeSpan] in
                var part = region
                part.span = stretch
                return edit.editedSpans(of: part, in: timeline)
            }
            let label = region.subject == .face ? region.subject.label : region.style.label
            return spans.enumerated().map { index, span in
                BlurInstance(
                    id: BlurInstance.id(region.id, index), regionID: region.id, span: span,
                    warnings: warnings.filter { $0.overlaps(span) }, label: label
                )
            }
        }
        .sorted { $0.span.start < $1.span.start }
    }

    /// How long, all areas together, may not cover what they hide.
    var uncheckedBlurDuration: TimeInterval {
        edit.blurRegions.reduce(0) { $0 + $1.uncheckedDuration }
    }

    /// "Review" in the check before Done: the first area left unchecked, picked, at its stretch.
    func reviewUncheckedBlur() {
        showsBlurCheck = false
        guard let region = edit.blurRegions.first(where: { !$0.openUnchecked.isEmpty }) else { return }
        selection = .blur(region.id)
        panel = .blur
        blur.goToUnchecked()
    }

    /// "Continue anyway": the creator looked; Done goes on, and isn't stopped again until the edit changes.
    func continueDespiteUncheckedBlur() {
        showsBlurCheck = false
        blurCheckAccepted = true
        askIfReadyToPost()
    }

    /// The Blur areas' bars.
    var blurBars: [LayerBar] {
        blurInstances.map { instance in
            LayerBar(
                id: instance.id, kind: .blur, span: instance.span, title: instance.label, isSelected: instance.regionID == selectedBlurID,
                owner: instance.regionID
            )
        }
    }
}
