//
//  TransitionBackdrop.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The app as it was the moment an idea was sent, held still behind its star and drawn back (`TransitionDim`, as the rise). Under it the
/// script page opens and Scripts changes without being seen, and the star darkens one picture instead of the whole live app, whose glass,
/// sky and lists cost frames every time they moved (measured on an iPhone 15 Pro, 25/10/2026: the rise ran at 74 fps with the live app
/// behind it). The star's cover hides the way back to the live app.
struct TransitionBackdrop: View {
    let still: UIView

    @Environment(IdeaTransitionService.self) private var transition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrawnBack = false

    var body: some View {
        Still(view: still)
            .modifier(TransitionDim(amount: isDrawnBack ? 1 : 0, recedes: !reduceMotion))
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                // The rise's own curve, so the app goes back as the star leaves it; from the next frame, as the star's own (the page opens
                // under it in this one).
                Task { @MainActor in
                    withAnimation(
                        reduceMotion ? .easeOut(duration: 0.3 * transition.speed)
                            : .timingCurve(0.2, 0.8, 0.2, 1, duration: IdeaTransitionService.riseDuration * transition.speed)
                    ) { isDrawnBack = true }
                }
            }
    }

    /// A still of what the window's root shows now, as it was last drawn: taken before the changes of the tap reach the screen. Sheets
    /// presented over the root are not in it (they leave by themselves).
    static func takeStill() -> UIView? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        return window?.rootViewController?.view.snapshotView(afterScreenUpdates: false)
    }

    /// The still, at the size it was taken, from the top left: the backdrop covers the same window it came from.
    private struct Still: UIViewRepresentable {
        let view: UIView

        func makeUIView(context: Context) -> UIView {
            let container = UIView()
            container.isUserInteractionEnabled = false
            container.clipsToBounds = false
            view.frame.origin = .zero
            container.addSubview(view)
            return container
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }
}
