//
//  ToastView.swift
//  Cue Studio
//

import SwiftUI

/// Short confirmation shown at the top of the screen, with an optional button ("Undo").
struct ToastView: View {
    var message: String
    var action: ToastAction?
    var onAction: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.accText)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let action {
                Button(action: onAction) {
                    Text(action.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accText)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background(Palette.accSoft, in: Capsule())
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("toast.action")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, action == nil ? 16 : 6)
        .padding(.vertical, action == nil ? 10 : 0)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: action == nil ? .combine : .contain)
    }
}

#if DEBUG
#Preview {
    ToastView(message: "Saved as v2 — 3 takes stay with v1")
        .padding()
        .background(Palette.bg)
}
#endif
