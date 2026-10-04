//
//  CometTravel.swift
//  Cue Studio
//

import SwiftUI

/// A comet along a route: the route draws while a glowing head (24 to 34 pt of light) moves along it
/// with a tail 14 to 18% of the path long. It is what the first voyage and the send-off use for "your
/// video is on its way". Under Reduce Motion the route simply appears.
struct CometTravel: View, Animatable {
    /// The route, in the view's own coordinates.
    let path: Path
    /// 0...1 along the route.
    var progress: Double
    var color: Color = Palette.acc
    var headSize: CGFloat = 28
    var tailFraction: Double = 0.16
    var showsRoute = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// SwiftUI animates `progress` itself, so `withAnimation { progress = 1 }` plays the whole trip.
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            if showsRoute {
                path.trimmedPath(from: 0, to: reduceMotion ? 1 : progress)
                    .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            if !reduceMotion, progress > 0, progress < 1 {
                path.trimmedPath(from: max(0, progress - tailFraction), to: progress)
                    .stroke(
                        color.opacity(0.9),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .shadow(color: color.opacity(0.7), radius: 6)
                if let head = Self.point(on: path, at: progress) {
                    Circle()
                        .fill(RadialGradient(colors: [.white, color, color.opacity(0)], center: .center, startRadius: 0, endRadius: headSize / 2))
                        .frame(width: headSize, height: headSize)
                        .position(head)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The point of `path` at `fraction` of its length.
    static func point(on path: Path, at fraction: Double) -> CGPoint? {
        let trimmed = path.trimmedPath(from: 0, to: min(1, max(0, fraction)))
        return trimmed.currentPoint
    }
}

/// Plays a comet once when `trigger` changes: it travels `duration` seconds along `path`.
struct CometPlayer: View {
    let path: Path
    var trigger: Int
    var duration = 1.6
    var color: Color = Palette.acc

    @State private var progress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CometTravel(path: path, progress: progress, color: color)
            .onChange(of: trigger, initial: false) { _, _ in
                progress = 0
                withAnimation(CueMotion.animation(CueMotion.travel(duration: duration), reduced: reduceMotion)) {
                    progress = 1
                }
            }
    }
}
