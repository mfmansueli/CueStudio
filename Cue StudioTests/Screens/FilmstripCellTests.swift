//
//  FilmstripCellTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

/// The take review's filmstrip grew over the title below it: portrait frames filled into short
/// cells took their own (taller) height.
@MainActor
@Suite("FilmstripCell")
struct FilmstripCellTests {
    private let cell = CGSize(width: 50, height: 36)

    @Test func aPortraitFrameKeepsTheCellsHeight() {
        let portrait = UIGraphicsImageRenderer(size: CGSize(width: 108, height: 192)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 108, height: 192))
        }
        let size = UIHostingController(rootView: FilmstripCell(image: portrait)).sizeThatFits(in: cell)
        #expect(size == cell)
    }

    @Test func aPlaceholderKeepsTheCellsHeight() {
        let size = UIHostingController(rootView: FilmstripCell(image: nil)).sizeThatFits(in: cell)
        #expect(size == cell)
    }
}
