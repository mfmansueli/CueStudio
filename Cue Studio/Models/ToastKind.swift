//
//  ToastKind.swift
//  Cue Studio
//

import Foundation

/// What a toast says, in the colour of its round icon: a glance tells the kind before the words are read.
nonisolated enum ToastKind: Hashable, Sendable {
    /// What the creator did is done, or was already so ("Duplicated", "Every cut already has it"): a green ✓ that draws itself.
    case done
    /// Cue decided something for the creator: wrote, fitted, captioned, found the beats, followed, learned ("Fitted to 1:00 to
    /// 1:30"): a yellow ★ that turns in, with a light tap.
    case cue
    /// Nothing happened, or only part of it, and why ("Move playhead onto the clip", "Couldn’t draft it"): an orange
    /// ! that shakes its head, with the warning tap.
    case problem
    /// Work under way ("Freezing the frame…"): a turning ring, until the toast that ends the work takes its place in the same
    /// pill (`ToastService.showWorking`).
    case working
}
