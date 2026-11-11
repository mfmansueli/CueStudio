import SwiftUI
import Testing
@testable import Cue_Studio

/// The recorder's panel ends as low as Scripts' tab bar on a phone with a Home Indicator, and where it was on one without.
@MainActor
struct FloatingBottomBarPlacementTests {
    @Test func aPhoneWithAHomeIndicatorLowersTheBarToTheTabBar() {
        // iPhone 17: a 34 pt strip; the tab bar ends 21 pt over the edge.
        #expect(FloatingBottomBarPlacement.drop(homeIndicatorStrip: 34) == 13)
        #expect(34 - FloatingBottomBarPlacement.drop(homeIndicatorStrip: 34) == Metrics.floatingBarBottom)
    }

    @Test(arguments: [0, 20, 21] as [CGFloat])
    func aShorterStripLeavesTheBarWhereItWas(strip: CGFloat) {
        #expect(FloatingBottomBarPlacement.drop(homeIndicatorStrip: strip) == 0)
    }
}
