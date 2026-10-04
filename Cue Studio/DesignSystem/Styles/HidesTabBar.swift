//
//  HidesTabBar.swift
//  Cue Studio
//

import SwiftUI

/// While this screen is up (and `hides` is true), the floating tab bar steps out of the way: the script
/// page and a list in selection mode need the room.
private struct HidesCueTabBar: ViewModifier {
    let hides: Bool

    @Environment(PresentationService.self) private var presentation
    @State private var isHiding = false

    func body(content: Content) -> some View {
        content
            .onAppear { sync(hides) }
            .onChange(of: hides) { _, hides in sync(hides) }
            .onDisappear { sync(false) }
    }

    private func sync(_ hides: Bool) {
        guard hides != isHiding else { return }
        isHiding = hides
        if hides { presentation.hideTabBar() } else { presentation.showTabBar() }
    }
}

extension View {
    func hidesCueTabBar(_ hides: Bool = true) -> some View {
        modifier(HidesCueTabBar(hides: hides))
    }
}
