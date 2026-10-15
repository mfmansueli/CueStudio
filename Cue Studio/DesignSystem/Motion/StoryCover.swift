//
//  StoryCover.swift
//  Cue Studio
//

import SwiftUI

/// A story told over the whole screen (the first star, a milestone) that fades in over what is under it and fades out again, instead of
/// sliding up like a sheet: the screen behind stays where it is and the night comes over it, so the story reads as a moment of the same place,
/// not a new page. The cover itself appears and goes without the system's slide (`disablesAnimations`); the fade is the story's own (0.35 s
/// in on light's curve, 0.25 s out). Callers set `isPresented` as they would for `fullScreenCover`.
struct StoryCover<Story: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let story: () -> Story

    /// The cover is up.
    @State private var isShown = false
    /// The story can be seen (its fade).
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isShown) {
                story()
                    .opacity(isVisible ? 1 : 0)
                    .presentationBackground(.clear)
                    // The screen behind shows through only during the fade: VoiceOver stays in the story.
                    .accessibilityAddTraits(.isModal)
                    .onAppear { withAnimation(CueMotion.storyIn) { isVisible = true } }
            }
            .onChange(of: isPresented, initial: true) { _, wanted in
                if wanted, !isShown {
                    isVisible = false
                    withoutSlide { isShown = true }
                } else if !wanted, isShown {
                    withAnimation(CueMotion.storyOut) { isVisible = false } completion: { withoutSlide { isShown = false } }
                }
            }
            // Dismissed some other way: the caller hears it.
            .onChange(of: isShown) { _, shown in
                if !shown, isPresented { isPresented = false }
            }
    }

    private func withoutSlide(_ change: () -> Void) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant, change)
    }
}

extension View {
    /// A full-screen story that fades in and out over this view (`StoryCover`).
    func storyCover<Story: View>(isPresented: Binding<Bool>, @ViewBuilder story: @escaping () -> Story) -> some View {
        modifier(StoryCover(isPresented: isPresented, story: story))
    }
}
