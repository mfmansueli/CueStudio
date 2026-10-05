//
//  KeepScreenAwake.swift
//  Cue StudioTests
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A run on a device takes many minutes; a phone that locks in the middle stops the test host ("Xcode cannot launch
/// … because the device is locked") and an app in the background is rate limited by the model. Every suite that runs on a
/// device keeps the screen awake while it runs (the phone still has to be unlocked when the run starts).
enum KeepScreenAwake {
    @MainActor
    static func enable() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }
}
