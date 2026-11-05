//
//  DockPlaces.swift
//  Cue Studio
//

import CoreGraphics

/// Where the dock's send arrow and writer chip last were, kept outside SwiftUI's state. They move with every frame while the dock folds
/// or unfolds under a scrolling list, and written to the dock's state each time they redrew the whole dock every frame (8 ms each on an
/// iPhone 15 Pro: frames held past 16.7 ms). Only a send (the star leaves from the arrow) and Ultra AI's ✦ flights read them, each time
/// the dock is drawn for that moment.
final class DockPlaces {
    /// The send arrow's centre in the window: where an idea's star starts.
    var sendCenter = CGPoint.zero
    /// The send arrow's centre in the dock (`ScriptsDock.ultraSpace`).
    var sendStar: CGPoint?
    /// The writer chip's frame in the dock.
    var writerFrame: CGRect?
}
