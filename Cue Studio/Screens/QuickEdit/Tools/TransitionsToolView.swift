//
//  TransitionsToolView.swift
//  Cue Studio
//

import SwiftUI

/// Transitions: every cut in the edit with None, Fade, Dissolve or Slide, and one row to set them
/// all. Every cut starts as None (a hard cut). Without cuts, how to make one.
struct TransitionsToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let cuts = viewModel.cuts
        if cuts.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "square.split.1x2")
                    .font(.title2)
                    .foregroundStyle(Palette.ink2)
                Text("No cuts yet").font(.headline)
                Text("Split the video in Trim, then pick how each part hands over.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                Button("Go to Trim") { viewModel.tool = .trim }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .accessibilityIdentifier("edit.transitions.goToTrim")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    if cuts.count > 1 { allCutsRow }
                    ForEach(Array(cuts.enumerated()), id: \.element.index) { number, cut in
                        row(
                            title: String(localized: "Cut \(number + 1) · \(DurationText.timecode(cut.time, total: viewModel.edit.editedDuration))"),
                            selected: viewModel.edit.timeline.transition(atJoin: cut.index),
                            identifier: "edit.transitions.cut\(number + 1)"
                        ) { viewModel.setTransition($0, atJoin: cut.index) }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var allCutsRow: some View {
        let transitions = Set(viewModel.cuts.map { viewModel.edit.timeline.transition(atJoin: $0.index) })
        return row(
            title: String(localized: "Every cut"),
            selected: transitions.count == 1 ? transitions.first : nil,
            identifier: "edit.transitions.all"
        ) { viewModel.setTransitionOnEveryCut($0) }
    }

    private func row(
        title: String, selected: EditTransition?, identifier: String, pick: @escaping (EditTransition) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.ink2)
            HStack(spacing: 6) {
                ForEach(EditTransition.allCases) { transition in
                    Button { pick(transition) } label: {
                        FilterChip(label: transition.label, isSelected: transition == selected, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(transition == selected ? .isSelected : [])
                    .accessibilityIdentifier("\(identifier).\(transition.rawValue)")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
