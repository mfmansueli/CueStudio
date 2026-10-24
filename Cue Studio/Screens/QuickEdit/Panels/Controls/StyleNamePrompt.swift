//
//  StyleNamePrompt.swift
//  Cue Studio
//

import SwiftUI

/// Naming a style: when it is saved (the next free "My style N" suggested) or renamed (its name to change).
struct StyleNameRequest: Identifiable, Equatable {
    enum Purpose: Equatable {
        case save
        case rename(UUID)
    }

    let id = UUID()
    let purpose: Purpose
    let name: String
}

/// The alert that asks for a style's name: Save or Rename, Cancel leaves everything as it was.
struct StyleNamePrompt: ViewModifier {
    @Binding var request: StyleNameRequest?
    let onName: (StyleNameRequest.Purpose, String) -> Void
    @State private var typed = ""

    func body(content: Content) -> some View {
        content
            .alert(
                request?.purpose == .save ? String(localized: "Save style") : String(localized: "Rename style"),
                isPresented: Binding(get: { request != nil }, set: { if !$0 { request = nil } }),
                presenting: request
            ) { asked in
                TextField(String(localized: "Name"), text: $typed)
                    .accessibilityIdentifier("edit.styleName.field")
                Button(String(localized: "Cancel"), role: .cancel) { request = nil }
                Button(asked.purpose == .save ? String(localized: "Save") : String(localized: "Rename")) {
                    onName(asked.purpose, typed)
                    request = nil
                }
                .accessibilityIdentifier("edit.styleName.done")
            } message: { _ in
                Text("Videos already made keep their own look.")
            }
            .onChange(of: request) { _, asked in typed = asked?.name ?? "" }
    }
}

extension View {
    func styleNamePrompt(_ request: Binding<StyleNameRequest?>, onName: @escaping (StyleNameRequest.Purpose, String) -> Void) -> some View {
        modifier(StyleNamePrompt(request: request, onName: onName))
    }
}
