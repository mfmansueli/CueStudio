//
//  StateChip.swift
//  Cue Studio
//

import SwiftUI

/// A script's state as a chip (v29): READY (green), DRAFT or RECORDED (quiet gray). 22 pt tall, mono 9.5 pt capitals
/// with .08em tracking. The state is always the word, never only the color.
struct StateChip: View {
    enum Kind: CaseIterable, Sendable {
        case ready, draft, recorded

        var title: LocalizedStringKey {
            switch self {
            case .ready: "Ready"
            case .draft: "Draft"
            case .recorded: "Recorded"
            }
        }

        var ink: Color {
            switch self {
            case .ready: Palette.stateReadyInk
            case .draft: Palette.stateDraftInk
            case .recorded: Palette.stateRecordedInk
            }
        }

        var fill: Color {
            switch self {
            case .ready: Palette.stateReadyFill
            case .draft: Palette.stateDraftFill
            case .recorded: Palette.stateRecordedFill
            }
        }
    }

    var kind: Kind

    var body: some View {
        Text(kind.title)
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .textCase(.uppercase)
            .tracking(9.5 * 0.08)
            .foregroundStyle(kind.ink)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: Metrics.stateChipHeight)
            .background(kind.fill, in: Capsule())
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 8) {
        ForEach(StateChip.Kind.allCases, id: \.self) { StateChip(kind: $0) }
    }
    .padding()
    .background(Palette.surface)
}
#endif
