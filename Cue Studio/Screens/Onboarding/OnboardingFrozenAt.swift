//
//  OnboardingFrozenAt.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// UI tests taking pictures: the first flight's chapter on screen (the practice, which lives in the prompter) stands still at this second
    /// of its timeline (`-uiTestChapterAt`).
    @Entry var onboardingChapterFrozenAt: Double?
}
