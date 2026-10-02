//
//  DictationButton.swift
//  Cue Studio
//

import SwiftUI

/// The microphone next to the idea field in the card: it starts dictating, and
/// while Cue prepares or listens it becomes a stop control (a red square in a red ring, as in
/// recording), so one tap always ends it. No press and hold: a creator who pauses to think keeps talking.
struct DictationButton: View {
    let state: DictationState
    let action: () -> Void

    private var isStop: Bool { state.isActive }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Palette.overlayFill)
                if isStop {
                    Circle().strokeBorder(Palette.record, lineWidth: 2)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Palette.record)
                        .frame(width: 11, height: 11)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                }
            }
            .frame(width: 34, height: 34)
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // Once stopped, the last words are being finalized: nothing to do until they are in.
        .disabled(state == .finishing)
        .opacity(state == .finishing ? 0.5 : 1)
        .accessibilityLabel(isStop ? Text("Stop dictation") : Text("Dictate your idea"))
        .accessibilityHint(isStop ? Text(verbatim: "") : Text("Your words appear here to review before you send."))
        .accessibilityIdentifier("ideaCard.dictate")
    }
}

#if DEBUG
#Preview {
    HStack {
        DictationButton(state: .idle) {}
        DictationButton(state: .listening) {}
        DictationButton(state: .finishing) {}
    }
    .padding()
    .background(Palette.insetField)
    .background(Palette.bg)
}
#endif
