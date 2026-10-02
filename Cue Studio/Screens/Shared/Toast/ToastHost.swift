//
//  ToastHost.swift
//  Cue Studio
//

import SwiftUI

/// Shows the current toast over the view. Apply it to every full-screen container (root, prompter)
/// so the toast is visible above covers.
struct ToastHost: ViewModifier {
    @Environment(ToastService.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = toast.message {
                    ToastView(message: message, action: toast.action) {
                        toast.action?.perform()
                        toast.dismiss()
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 8)
                    .id(message)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .onTapGesture { toast.dismiss() }
                    .accessibilityIdentifier("toast")
                }
            }
            .animation(.spring(duration: 0.3), value: toast.message)
    }
}

extension View {
    func toastHost() -> some View {
        modifier(ToastHost())
    }
}
