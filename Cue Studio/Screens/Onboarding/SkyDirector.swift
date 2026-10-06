//
//  SkyDirector.swift
//  Cue Studio
//

import SwiftUI

/// The sky behind the first flight is one view for every chapter, but a chapter sometimes moves it (1.3 pulls the camera back: the sky zooms
/// less than the foreground, ×1.5 → ×1, so the pull-back has depth; and it drifts a little as a light crosses it). The chapter that wants that
/// writes the pose here and `OnboardingSky` reads it.
@MainActor
@Observable
final class SkyDirector {
    var pose = MotionPose()
}
