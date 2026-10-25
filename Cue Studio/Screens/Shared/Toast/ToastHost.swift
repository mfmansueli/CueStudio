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
                    ToastView(message: message, kind: toast.kind, action: toast.action) {
                        toast.action?.perform()
                        toast.dismiss()
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 8)
                    // Work under way that ends keeps its pill (`ToastService.pill`): only a new toast comes in anew.
                    .id(toast.pill)
                    .transition(.toast(reduceMotion: reduceMotion))
                    .onTapGesture { toast.dismiss() }
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
