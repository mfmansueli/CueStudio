//
//  FilterFanPlace.swift
//  Cue Studio
//

import CoreGraphics

/// Where the row last was in the window, kept outside SwiftUI's state: the row moves with every frame of a scroll, and a frame written to
/// the screen's `FilterFanState` each time redrew the whole screen while the finger dragged. The state takes it only while the row is open.
final class FilterFanPlace {
    var frame: CGRect = .zero
}
