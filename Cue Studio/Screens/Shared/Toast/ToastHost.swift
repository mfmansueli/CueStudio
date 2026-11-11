//
//  ToastHost.swift
//  Cue Studio
//

import SwiftUI

/// Shows the current toast over the view. Apply it to every full-screen container (root, prompter)
/// so the toast is visible above covers, and to a sheet whose own actions say something (`inSheet`): while that sheet is up, it shows the
/// toast instead of the root and the prompter, as the editor's host does while the editor is up (`ToastService.frontHosts`).
struct ToastHost: ViewModifier {
    var inSheet = false

    @Environment(ToastService.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = toast.message, inSheet || toast.frontHosts == 0 {
                    ToastView(
                        message: message, kind: toast.kind, action: toast.action,
                        onAction: {
                            toast.action?.perform()
                            toast.dismiss()
                        },
                        secondaryAction: toast.secondaryAction,
                        onSecondaryAction: {
                            toast.secondaryAction?.perform()
                            toast.dismiss()
                        }
                    )
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 8)
                    // Work under way that ends keeps its pill (`ToastService.pill`): only a new toast comes in anew.
                    .id(toast.pill)
                    .transition(.toast(reduceMotion: reduceMotion))
                    // A tap on the words lets a plain toast go; one with a button keeps it until its time is up, so a tap meant
                    // for the screen beneath never throws an Undo away.
                    .onTapGesture { if toast.action == nil { toast.dismiss() } }
                }
            }
            .animation(.spring(duration: 0.3), value: toast.message)
            .onAppear { if inSheet { toast.frontHostAppeared() } }
            .onDisappear { if inSheet { toast.frontHostDisappeared() } }
    }
}

extension View {
    func toastHost(inSheet: Bool = false) -> some View {
        modifier(ToastHost(inSheet: inSheet))
    }
}
