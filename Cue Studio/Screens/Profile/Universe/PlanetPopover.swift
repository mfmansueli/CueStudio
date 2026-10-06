//
//  PlanetPopover.swift
//  Cue Studio
//

import SwiftUI

/// What a tap on a planet says (9.2): "● TikTok", "12 VIDEOS IN 2026", "40 more to unlock brighter glow" (the live year only) and **See in Takes ›**.
struct PlanetPopover: View {
    let platform: Platform
    let count: Int
    let year: Int
    let isLive: Bool
    let onSeeInTakes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Circle().fill(platform.tint).frame(width: 7, height: 7)
                Text(platform.label).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
            }
            Text("\(count) VIDEOS IN \(String(year))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Palette.accText)
            if isLive, let next = PlanetSize.next(videos: count) {
                Text("\(next.remaining) more to unlock \(PlanetPopover.detailName(next.detail))")
                    .font(.system(size: 12.5)).foregroundStyle(Palette.ink2).lineLimit(1).minimumScaleFactor(0.85)
            }
            Button(action: onSeeInTakes) {
                Text("See in Takes ›").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity).frame(height: 32)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 5)
            .accessibilityIdentifier("universe.planetSeeInTakes")
        }
        .padding(14)
        .background(Palette.popover, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.glassBorder.opacity(0.8), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
        .accessibilityElement(children: .contain)
    }

    /// What the next detail is called in "N more to unlock …".
    static func detailName(_ detail: PlanetSize.Detail) -> String {
        switch detail {
        case .sphere, .glow: String(localized: "brighter glow")
        case .ring: String(localized: "a thin ring")
        case .moon: String(localized: "a small moon")
        }
    }
}
