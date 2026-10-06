//
//  PosterLayoutTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

/// A take's poster never makes its screen wider than the screen, whatever shape the recording has (a landscape or square one used to stretch "Ready to
/// travel" to the width of the whole picture, off both edges of the phone).
@MainActor
@Suite("Poster layout")
struct PosterLayoutTests {
    private func picture(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// The width the poster takes in the way "Ready to travel" lays it out (9:16, at most 400 pt tall) inside a 390 pt column.
    private func width(of image: UIImage?) -> CGFloat {
        let view = PosterImage(image: image)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxHeight: 400)
        let host = UIHostingController(rootView: view)
        return host.sizeThatFits(in: CGSize(width: 390, height: 800)).width
    }

    @Test(arguments: [(1920.0, 1080.0), (1080.0, 1080.0), (1080.0, 1350.0), (1080.0, 1920.0), (4000.0, 3000.0)])
    func aPosterOfAnyShapeKeepsItsColumn(size: (Double, Double)) {
        #expect(width(of: picture(width: size.0, height: size.1)) <= 390)
    }

    @Test func aPosterStillLoadingKeepsItsColumnToo() {
        #expect(width(of: nil) <= 390)
    }

    @Test func theNineBySixteenFrameStaysNineBySixteen() {
        #expect(abs(width(of: picture(width: 1920, height: 1080)) - 225) < 1)
    }

    /// The way the poster used to be drawn (the picture in the same stack as its gradient, filled and clipped): the measuring here sees its overflow, so
    /// the tests above are really looking at the cause.
    private struct FilledInTheSameStack: View {
        let image: UIImage

        var body: some View {
            ZStack {
                LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
                Image(uiImage: image).resizable().scaledToFill()
            }
            .clipped()
        }
    }

    @Test func theMeasuringSeesWhatTheOldDrawingDid() {
        let view = FilledInTheSameStack(image: picture(width: 1920, height: 1080))
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxHeight: 400)
        let size = UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: 390, height: 800))
        #expect(size.width > 390, "a landscape picture stretched its stack to \(size.width) pt")
    }
}
