//
//  VoyageStepRow.swift
//  Cue Studio
//

import SwiftUI

/// One step in the list: a yellow check when done, a yellow ring when it is next (with its Start button), its number ahead.
struct VoyageStepRow: View {
    enum State {
        case done, next, ahead
    }

    let step: VoyageStep
    let state: State
    var onStart: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            mark
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(state == .next ? Palette.aiText : Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if state == .next {
                Button("Start", action: onStart)
                    .buttonStyle(.cuePrimary(.compact, expands: false))
                    .accessibilityIdentifier("voyage.step.start")
            }
        }
        .frame(minHeight: 56)
        .padding(.horizontal, state == .next ? 12 : 0)
        .background {
            if state == .next {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.aiFill)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.aiBorder, lineWidth: 1))
            }
        }
        .padding(.horizontal, state == .next ? -12 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(stateLabel))
        .accessibilityIdentifier("voyage.step.\(step.number)")
    }

    private var detail: String {
        switch state {
        case .done: String(localized: "Done")
        case .next: String(localized: "Next · \(step.detail)")
        case .ahead: step.detail
        }
    }

    private var stateLabel: String {
        switch state {
        case .done: String(localized: "Done")
        case .next: String(localized: "Next")
        case .ahead: String(localized: "Not done yet")
        }
    }

    @ViewBuilder
    private var mark: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Palette.accInk)
                .frame(width: 28, height: 28)
                .background(Palette.acc, in: Circle())
        case .next:
            Circle()
                .strokeBorder(Palette.acc, lineWidth: 2)
                .frame(width: 28, height: 28)
                .overlay(Circle().fill(Palette.acc).frame(width: 10, height: 10))
        case .ahead:
            Text("\(step.number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.ink2)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(Palette.ink3, lineWidth: 2))
        }
    }
}
