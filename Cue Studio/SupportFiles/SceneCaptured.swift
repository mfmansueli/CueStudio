//
//  SceneCaptured.swift
//  Cue Studio
//

import SwiftUI

/// Whether the scene this view is in is being recorded, mirrored or AirPlayed: SwiftUI's `isSceneCaptured`, which follows the
/// scene's `UITraitCollection.sceneCaptureState` (iOS 17+, the replacement for `UIScreen.isCaptured`). It belongs to the view's
/// own scene (on iPad another window can be captured while this one isn't), it is already true when the view appears during a
/// capture that started earlier (before launch, or on another screen), and the system keeps it current as capture starts and
/// stops, the view moves to another scene or the app comes back to the foreground. Cue's own camera and voice-over recordings
/// never set it: only the system capturing the screen does.
///
/// On the free plan, video surfaces carry Cue's mark while it is true (`CaptureWatermark`); on Pro nothing changes. Detection
/// is all iOS offers: the frame on screen when capture starts may make it into the recording before SwiftUI draws the mark.
@MainActor
@propertyWrapper
struct SceneCaptured: DynamicProperty {
    @Environment(\.isSceneCaptured) private var isSceneCaptured

    var wrappedValue: Bool {
        #if DEBUG
        // UI tests turn capture on and off (`-uiTestSceneCapture`): the Simulator's own recording never sets the trait.
        if SimulatedSceneCapture.shared.isActive { return true }
        #endif
        return isSceneCaptured
    }
}
