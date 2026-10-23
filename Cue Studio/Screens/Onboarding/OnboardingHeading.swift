//
//  OnboardingHeading.swift
//  Cue Studio
//

import SwiftUI

/// A chapter's heading: its label in yellow mono, the title and the line under it. Each rises out of a blur (the boards: 16 pt up, 10 pt of
/// blur, 0.75 s, `cubic-bezier(.16,1,.3,1)`, the three a little apart). A chapter that plays its board gives the pose of each piece at the
/// second it is drawing (`poses`: label, title, line); without them the heading plays its own short arrival.
struct OnboardingHeading: View {
    let label: String
    let title: String
    var subtitle: String?
    var poses: [MotionPose]?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .hudFont()
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(Palette.accText)
                // The chapter's name wraps rather than ending in "…" when a long language or large type squeezes the page.
                .fixedSize(horizontal: false, vertical: true)
                .motion(pose(0))
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .motion(pose(1, own: MotionPose(opacity: shown ? 1 : 0, ty: shown || reduceMotion ? 0 : 16, blur: shown || reduceMotion ? 0 : 10)))
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .motion(pose(2, own: MotionPose(opacity: shown ? 1 : 0)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard poses == nil else { return }
            withAnimation(CueMotion.animation(CueMotion.light(duration: 0.8), reduced: reduceMotion)) { shown = true }
        }
    }

    /// The board's pose of piece `index`, or the heading's own arrival (`own`) when it has no board; the label has none of its own.
    private func pose(_ index: Int, own: MotionPose = MotionPose()) -> MotionPose {
        guard let poses else { return own }
        return poses.indices.contains(index) ? poses[index] : MotionPose()
    }
}
