//
//  PreviewEnvironment.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// Injects the preview services (in-memory storage, sample scripts) into a preview.
struct PreviewEnvironment: ViewModifier {
    let seeded: Bool

    func body(content: Content) -> some View {
        content
            .environment(seeded ? AppServices.preview : AppServices.previewEmpty)
            .preferredColorScheme(.dark)
    }
}

extension View {
    func previewEnvironment(seeded: Bool = true) -> some View {
        modifier(PreviewEnvironment(seeded: seeded))
    }
}
#endif
