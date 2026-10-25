//
//  EditorToastHost.swift
//  Cue Studio
//

import SwiftUI

/// The editor's toasts: the app's toast (`ToastView`, with its kind's icon) at the top of the preview, for 2 s. They confirm an
/// action or say why one can't happen ("Move the playhead inside the clip"); a tap lets one go early. One with an action
/// ("8 lines deleted" · Undo) shows its button at the end of the pill and stays 4 s (`ToastService`).
struct EditorToastHost: ViewModifier {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    // Work under way that ends keeps its pill (`ToastService.pill`): only a new toast comes in anew.
                    .id(toast.pill)
                    .transition(.toast(reduceMotion: reduceMotion))
                    .onTapGesture { toast.dismiss() }
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.2), value: toast.message)
            .onAppear { toast.defaultDuration = .seconds(2) }
            .onDisappear { toast.defaultDuration = .seconds(2.4) }
    }
}
