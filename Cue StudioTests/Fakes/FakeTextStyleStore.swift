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
    var myCoverLook: CoverLook?

    init(myStyle: TextLook? = nil, myCoverLook: CoverLook? = nil) {
        self.myStyle = myStyle
        self.myCoverLook = myCoverLook
    }
}
