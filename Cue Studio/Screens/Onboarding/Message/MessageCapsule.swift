//
//  MessageCapsule.swift
//  Cue Studio
//

import SwiftUI

/// "MESSAGE READY FOR LAUNCH" under the card (1.4): a yellow capsule with a glowing star that pulses, and, once it has risen, a bright dot with a
/// tail that runs along it, uncovering the words as it goes, a thin line growing under it, and a ring where it ends (09 §16).
struct MessageCapsule: View {
    /// The second of the board (`MessageTimeline`) and the time since the chapter appeared (for the star's pulse).
    let board: Double
    let ambient: Double
    /// The label ("MESSAGE READY FOR LAUNCH", or the built-in message's).
    let label: String

    private static let clip = MotionLibrary.clip("1.4_first-message")

    var body: some View {
        let reveal = Self.clip.pose(of: "L50", at: board).clipRight ?? 1
        HStack(spacing: 10) {
            star
            Text(label)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .tracking(1.15)
                .foregroundStyle(Palette.Universe.starGold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .mask(alignment: .leading) { GeometryReader { Rectangle().frame(width: $0.size.width * max(0, min(1, 1 - reveal))) } }
            Spacer(minLength: 0)
        }
        .padding(.leading, 5)
        .padding(.trailing, 14)
        .frame(height: 40)
        .background(Palette.acc.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.acc.opacity(0.4), lineWidth: 1))
        .shadow(color: Palette.acc.opacity(0.16), radius: 11)
        .overlay { run }
        .motion(Self.clip.pose(of: "L48", at: board))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
    }

    /// The star: a lit orb (`#FFF6C2 → #FFD60A → #C99600`), black ✦ on it, and a ring that opens from it every 2 s.
    private var star: some View {
        let pulse = Self.clip.pose(of: "L49", at: ambient, loops: true)
        return ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Palette.Universe.starCream, Palette.acc, Palette.Flight.goldEdge],
                    center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 22
                ))
                .frame(width: 30, height: 30)
                .shadow(color: Palette.acc.opacity(0.8), radius: 7)
            Circle()
                .strokeBorder(Palette.acc, lineWidth: 1.5)
                .frame(width: 38, height: 38)
                .motion(pulse)
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)
        }
        .frame(width: 30, height: 30)
    }

    /// The dot and its tail running to the end, the line growing under it, the ring at the end.
    private var run: some View {
        GeometryReader { proxy in
            let line = Self.clip.pose(of: "L51", at: board)
            let dot = Self.clip.pose(of: "L52", at: board)
            let burst = Self.clip.pose(of: "L53", at: board)
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    stops: [
                        .init(color: Palette.acc.opacity(0), location: 0), .init(color: Palette.acc.opacity(0.7), location: 0.6),
                        .init(color: Palette.Universe.starCream, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: max(0, width - 62), height: 1.5)
                .clipShape(Capsule())
                .shadow(color: Palette.acc.opacity(0.6), radius: 4)
                .scaleEffect(x: line.sx, anchor: .leading)
                .opacity(line.opacity)
                .offset(x: 46, y: proxy.size.height - 8.5)
                runner.opacity(dot.opacity).offset(x: 46 + dot.tx, y: proxy.size.height / 2)
                Circle()
                    .strokeBorder(Palette.Universe.starGold, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .motion(burst)
                    .offset(x: width - 14 - 22, y: proxy.size.height / 2 - 11)
            }
        }
        .allowsHitTesting(false)
    }

    /// The bright dot with a 46 pt tail behind it; its centre is at the origin.
    private var runner: some View {
        ZStack {
            LinearGradient(colors: [Palette.Universe.starCream.opacity(0), Palette.acc.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 46, height: 2)
                .clipShape(Capsule())
                .offset(x: -23)
            Circle()
                .fill(RadialGradient(colors: [.white, Palette.Universe.starCream, Palette.acc], center: .center, startRadius: 0, endRadius: 5))
                .frame(width: 10, height: 10)
                .shadow(color: Palette.acc.opacity(0.85), radius: 6)
        }
        .frame(width: 0, height: 0)
    }
}
