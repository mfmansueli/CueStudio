//
//  RecPill.swift
//  Cue Studio
//

import SwiftUI

/// The "● REC" pill (v29): the way into recording from a script. 26 pt to see (a 6 pt red dot, the label and a
/// 1 pt ring), 44 pt to touch. Red is for recording only, so this is the one place outside the recorder it
/// shows; the label stays `ink`.
struct RecPill: View {
    var action: () -> Void
    var accessibilityIdentifier: String?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Palette.Camera.recPillDot)
                    .frame(width: Metrics.recPillDotSize, height: Metrics.recPillDotSize)
                Text("REC")
                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, Metrics.recPillPadding)
            .frame(height: Metrics.recPillHeight)
            .overlay(Capsule().strokeBorder(Palette.Camera.recPillRing, lineWidth: 1))
            // The pill is 26 pt; the touch area is the 44 pt around it.
            .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityLabel(Text("Record"))
        .accessibilityIdentifier(accessibilityIdentifier ?? "recPill")
    }
}

#if DEBUG
#Preview {
    RecPill {}
        .padding()
        .background(Palette.bg)
}
#endif
