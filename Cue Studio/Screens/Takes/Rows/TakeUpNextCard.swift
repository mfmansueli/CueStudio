//
//  TakeUpNextCard.swift
//  Cue Studio
//

import SwiftUI

/// What to do next in Takes (6.2): the video that has waited longest, with its poster, "UP NEXT · POST IT" and one button for the step (Share, Edit
/// or Pick). The card opens the video; the button opens it at that step.
struct TakeUpNextCard: View {
    let next: TakePipeline.Next
    let onOpen: () -> Void
    let onAct: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    poster
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: eyebrow)
                        Text(next.video.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(next.stage.nextVerb ?? ""), \(next.video.title)"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("takes.next")
            Button(action: onAct) {
                Text(actionTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.accInk)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Palette.acc, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("takes.next.action")
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .tracking(1)
        .foregroundStyle(Palette.acc)
        .padding(.horizontal, 12)
        .frame(height: 76)
        .background {
            ZStack {
                Palette.surface
                RadialGradient(
                    colors: [Palette.Takes.upNextGlow, .clear], center: UnitPoint(x: 0, y: 0.5), startRadius: 0, endRadius: 300
                )
            }
            .clipShape(shape)
        }
        .overlay(shape.strokeBorder(Palette.Takes.upNextRim, lineWidth: 0.5))
    }

    @ViewBuilder
    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        Group {
            if let best = next.video.best { TakeThumbnail(take: best) } else { Palette.surface2 }
        }
        .frame(width: 40, height: 56)
        .clipShape(shape)
    }

    /// "UP NEXT · POST IT"
    private var eyebrow: String {
        "\(String(localized: "Up next").uppercased()) · \((next.stage.nextVerb ?? "").uppercased())"
    }

    private var actionTitle: String {
        switch next.stage {
        case .pick: String(localized: "Pick")
        case .edit: String(localized: "Edit")
        case .ready, .shared: String(localized: "Share")
        }
    }
}
