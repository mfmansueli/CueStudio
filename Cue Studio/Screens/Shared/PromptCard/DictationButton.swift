//
//  DictationButton.swift
//  Cue Studio
//

import SwiftUI

/// The microphone next to the idea field in the card: it starts dictating, and
/// while Cue prepares or listens it becomes a stop control (a red square in a red ring, as in
/// recording), so one tap always ends it. No press and hold: a creator who pauses to think keeps talking.
struct DictationButton: View {
    /// `plain`: the quiet microphone inside the field's box; `primary`: the yellow one of the bare first-visit card.
    enum Style { case plain, primary }

    let state: DictationState
    var style: Style = .plain
    let action: () -> Void

    private var isStop: Bool { state.isActive }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(style == .primary && !isStop ? Palette.acc : Color.clear)
                if isStop {
                    Circle().strokeBorder(Palette.record, lineWidth: 2)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Palette.record)
                        .frame(width: 11, height: 11)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: style == .primary ? 17 : 16, weight: .semibold))
                        .foregroundStyle(style == .primary ? Palette.accInk : Palette.aiTextStrong.opacity(0.8))
                }
            }
            .frame(width: style == .primary ? 40 : 36, height: style == .primary ? 40 : 36)
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
