//
//  EditorToastHost.swift
//  Cue Studio
//

import SwiftUI

/// The editor's toasts: one line on a dark pill with a small yellow star, at the top of the
/// preview, for 2 s. They confirm an action or say why one can't happen ("Move the playhead
/// inside the clip"); a tap lets one go early. One with an action ("8 lines deleted" · Undo) shows
/// its button at the end of the pill and stays 4 s (`ToastService`).
struct EditorToastHost: ViewModifier {
    /// Where the preview starts: the toast sits just under the top bar.
    let top: CGFloat

    @Environment(ToastService.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = toast.message {
                    HStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.accText)
                                .accessibilityHidden(true)
                            Text(message)
                                .font(.system(size: 13.5, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("toast")
                        if let action = toast.action {
                            Button {
                                action.perform()
                                toast.dismiss()
                            } label: {
                                Text(action.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Palette.accText)
                                    .padding(.horizontal, 10)
                                    .frame(height: 26)
                                    .background(Palette.accSoft, in: Capsule())
                                    .frame(minHeight: Metrics.hitTarget)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("toast.action")
                        }
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, toast.action == nil ? 14 : 4)
                    .frame(height: 34)
                    .background(Palette.editorToast, in: Capsule())
                    .padding(.horizontal, 16)
                    .padding(.top, top + 10)
                    .id(message)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .onTapGesture { toast.dismiss() }
                    .accessibilityElement(children: .contain)
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.2), value: toast.message)
            .onAppear { toast.defaultDuration = .seconds(2) }
            .onDisappear { toast.defaultDuration = .seconds(2.4) }
    }
}
