//
//  CueActionSheet.swift
//  Cue Studio
//

import SwiftUI

/// The confirmation the board draws (11.1 "reset confirm"): the page dims, and at the bottom a card with the question in grey and the one action in red,
/// and under it a separate **Cancel** card in bold. iOS 27's `confirmationDialog` opens as a bubble with no Cancel, so this one is Cue's own; it comes up
/// over the tab bar like the system's would, and a tap outside cancels.
struct CueActionSheet: ViewModifier {
    @Binding var isPresented: Bool
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let actionIdentifier: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Text(message)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    Rectangle().fill(Palette.separator).frame(height: 0.5)
                    Button {
                        isPresented = false
                        action()
                    } label: {
                        Text(actionTitle).font(.system(size: 19)).foregroundStyle(Palette.danger).frame(maxWidth: .infinity).frame(height: 56)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(actionIdentifier)
                }
                .background(Palette.surface3, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Button { isPresented = false } label: {
                    Text("Cancel").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity).frame(height: 56)
                }
                .buttonStyle(.plain)
                .background(Palette.surface3, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("actionSheet.cancel")
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(Color.clear.contentShape(Rectangle()).onTapGesture { isPresented = false })
            .presentationBackground(Color.black.opacity(0.4))
            // A container of its own: an identifier on the stack alone would replace the identifiers of the buttons in it.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("actionSheet")
        }
    }
}

extension View {
    /// A confirmation as the board draws it: a dimmed page, the question and the red action in a card, and Cancel under it.
    func cueActionSheet(
        isPresented: Binding<Bool>, message: LocalizedStringKey, actionTitle: LocalizedStringKey, actionIdentifier: String, action: @escaping () -> Void
    ) -> some View {
        modifier(CueActionSheet(isPresented: isPresented, message: message, actionTitle: actionTitle, actionIdentifier: actionIdentifier, action: action))
    }
}
