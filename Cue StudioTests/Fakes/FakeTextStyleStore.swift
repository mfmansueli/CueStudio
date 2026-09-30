//
//  FakeTextStyleStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// "My style" in memory, so tests never write the simulator's defaults.
@MainActor
final class FakeTextStyleStore: TextStyleStoring {
    var myStyle: TextLook?

    init(myStyle: TextLook? = nil) {
        self.myStyle = myStyle
    }
}
