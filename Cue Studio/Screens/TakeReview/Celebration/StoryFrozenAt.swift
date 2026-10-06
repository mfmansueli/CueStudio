//
//  StoryFrozenAt.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// UI tests taking pictures: the milestone (8.3) and first-star (1.7) stories stand still at this second (`-uiTestStoryAt`).
    @Entry var storyFrozenAt: Double?
}
