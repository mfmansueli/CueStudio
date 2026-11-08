//
//  ToastView.swift
//  Cue Studio
//

import SwiftUI

/// A toast (`ToastService`), the same in the whole app and the editor: its kind's round icon (`ToastIcon`), the message on a line
/// (two when a language needs them, so an instruction is never cut; at the accessibility text sizes as many as it needs, with
/// the buttons under it) and its button ("Undo") at the end, in the app's yellow, with
/// a quieter second one before it when the toast has two ("Change"), on the toasts' pill (`toastSurface(in:)`). When work under
/// way ends, the same pill turns into what came of it: a new icon arrives and the words cross-fade.
struct ToastView: View {
    var message: String
    var kind: ToastKind = .done
    var action: ToastAction?
    var onAction: () -> Void = {}
    /// Shown only beside `action`.
    var secondaryAction: ToastAction?
    var onSecondaryAction: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if stacksButtons {
                // At the accessibility text sizes a row cut the words to "Look auf…" and broke "Ändern" (SE, 08/11/2026): the
                // message gets the whole width and the buttons go under it.
                VStack(alignment: .trailing, spacing: 4) {
                    message(lineLimit: nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 10) { buttons }
                }
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 10) {
                    message(lineLimit: 2)
                    buttons
                }
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

    private var stacksButtons: Bool { action != nil && dynamicTypeSize.isAccessibilitySize }

    private func message(lineLimit: Int?) -> some View {
        HStack(spacing: 10) {
            ToastIcon(kind: kind)
                .id(kind)
                .transition(.opacity)
            Text(message)
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .padding(.vertical, action == nil ? 9 : 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("toast")
    }

    @ViewBuilder private var buttons: some View {
        if action != nil, let secondaryAction {
            Button(action: onSecondaryAction) {
                Text(secondaryAction.title)
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 8)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("toast.secondaryAction")
        }
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
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        ToastView(message: "Duplicated")
        ToastView(message: "Fitted to 1:00 to 1:30", kind: .cue, action: ToastAction(title: "Undo") {})
        ToastView(message: "Look pasted · 3 parts", action: ToastAction(title: "Undo") {}, secondaryAction: ToastAction(title: "Change") {})
        ToastView(message: "Couldn’t draft it", kind: .problem)
        ToastView(message: "Drafting the TikTok version…", kind: .working)
    }
    .padding()
    .background(Palette.bg)
}
#endif
