//
//  ToastView.swift
//  Cue Studio
//

import SwiftUI

/// A toast (`ToastService`), the same in the whole app and the editor: its kind's round icon (`ToastIcon`), the message on a line
/// (two when a language needs them, so an instruction is never cut) and its button ("Undo") at the end, in the app's yellow, on
/// the toasts' pill (`toastSurface(in:)`). When work under way ends, the same pill turns into what came of it: a new icon arrives
/// and the words cross-fade.
struct ToastView: View {
    var message: String
    var kind: ToastKind = .done
    var action: ToastAction?
    var onAction: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                ToastIcon(kind: kind)
                    .id(kind)
                    .transition(.opacity)
                Text(message)
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            .padding(.vertical, action == nil ? 9 : 6)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("toast")
            if let action {
                Button(action: onAction) {
                    Text(action.title)
                        .cueFont(.subheadline, weight: .semibold)
                        .foregroundStyle(Palette.accInk)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 32)
                        .background(Palette.acc, in: Capsule())
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("toast.action")
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, action == nil ? 16 : 6)
        .frame(minHeight: Metrics.hitTarget)
        .toastSurface(in: RoundedRectangle(cornerRadius: Metrics.toastRadius, style: .continuous))
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.3, bounce: 0.1), value: message)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.3, bounce: 0.1), value: kind)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        ToastView(message: "Duplicated")
        ToastView(message: "Fitted to 1:00 to 1:30", kind: .cue, action: ToastAction(title: "Undo") {})
        ToastView(message: "Couldn’t draft it · Try again", kind: .problem)
        ToastView(message: "Drafting the TikTok version…", kind: .working)
    }
    .padding()
    .background(Palette.bg)
}
#endif
