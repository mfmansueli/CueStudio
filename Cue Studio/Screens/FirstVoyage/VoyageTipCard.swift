//
//  VoyageTipCard.swift
//  Cue Studio
//

import SwiftUI

/// A first voyage tip, in Cue's one tip form (`TipCard`): the ★ disc (Cue guiding; violet is for AI), "4 OF 6" (which opens the list of
/// steps), what to do and why in a line, at most two buttons and ✕. Above the dock or the tab bar (`VoyageFloatingTip`), or in the place
/// its step happens (`VoyageInPlaceTip`), never over what it talks about. Done in place, its disc turns into a ✓ and the eyebrow says so
/// before it goes. The voyage decides when it shows (one at a time: the next step's).
struct VoyageTipCard: View {
    /// The step the eyebrow counts: the one the tip is about, or the one ahead (the first draft's tip).
    let step: VoyageStep
    let title: String
    let message: String
    var primary: (title: String, action: () -> Void)?
    var secondary: (title: String, action: () -> Void)?
    /// The step was just done here: ✓ and "4 OF 6 · DONE", no buttons.
    var isDone = false
    /// The tip's own name for UI tests ("voyage.tip.3", "voyage.tip.draft").
    var identifier: String?
    let onClose: () -> Void

    @State private var showsSteps = false

    var body: some View {
        TipCard(
            sign: isDone ? .done : .guide, title: Text(title), message: Text(message),
            primary: isDone ? nil : primary, secondary: isDone ? nil : secondary, identifierPrefix: "voyage.tip", onClose: onClose
        ) {
            eyebrow
        }
        .sheet(isPresented: $showsSteps) { VoyageStepsSheet() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier ?? "voyage.tip.\(step.number)")
    }

    private var eyebrowText: String {
        let count = VoyageProgress.stepCount
        return isDone ? String(localized: "\(step.number) OF \(count) · DONE") : String(localized: "\(step.number) OF \(count)")
    }

    /// "4 OF 6": where the creator is, and the way to every step.
    private var eyebrow: some View {
        Button { showsSteps = true } label: {
            Text(eyebrowText)
                .monoFont(size: 10.5, weight: .semibold)
                .interfaceTracking(1.2)
                .foregroundStyle(isDone ? Palette.successText : Palette.accText)
                .contentTransition(.numericText())
                .frame(minHeight: 20, alignment: .leading)
                // 44 pt to touch, without pushing the words down.
                .padding(.vertical, 12)
                .padding(.trailing, 16)
                .contentShape(Rectangle())
                .padding(.vertical, -12)
                .padding(.trailing, -16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Step \(step.number) of \(VoyageProgress.stepCount)"))
        .accessibilityHint(Text("Shows every step"))
        .accessibilityIdentifier("voyage.tip.steps")
    }
}
