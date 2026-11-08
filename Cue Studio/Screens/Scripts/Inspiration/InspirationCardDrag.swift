//
//  InspirationCardDrag.swift
//  Cue Studio
//

import Observation
import SwiftUI

/// How far the idea's card is dragged sideways, outside the sheet's state: it changes with every frame of the finger, and read by the sheet
/// it redrew all of it (header, topics, notes, actions) each time. Only the card reads it (`InspirationDraggedCard`).
@MainActor
@Observable
final class InspirationCardDrag {
    var offset: CGFloat = 0
}
