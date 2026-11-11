import SwiftUI

/// Places a bar that floats over a full-screen view (the recorder's controls, Selfie and Studio) as low as the system's tab bar on Scripts: its
/// bottom `Metrics.floatingBarBottom` over the screen's edge, inside the Home Indicator's strip, instead of on top of that strip. The view it
/// wraps fills the safe area and keeps its top where it was; only its bottom reaches lower. A screen whose strip is shorter (no Home Indicator,
/// iPad) leaves the bar where it was.
struct FloatingBottomBarPlacement: ViewModifier {
    /// How far the bar goes down into a Home Indicator strip of this height.
    static func drop(homeIndicatorStrip: CGFloat) -> CGFloat {
        max(0, homeIndicatorStrip - Metrics.floatingBarBottom)
    }

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .padding(.bottom, -Self.drop(homeIndicatorStrip: proxy.safeAreaInsets.bottom))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }
}

extension View {
    /// The bar at the bottom of this view sits as low as the system's tab bar (`FloatingBottomBarPlacement`).
    func floatingBottomBarPlacement() -> some View {
        modifier(FloatingBottomBarPlacement())
    }
}
