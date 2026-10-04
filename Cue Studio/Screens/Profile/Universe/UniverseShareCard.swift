//
//  UniverseShareCard.swift
//  Cue Studio
//

import SwiftUI

/// The picture "Share my universe" and "My year in Cue" send: a 9:16 card with the map or the year's numbers. Drawn
/// from what is on this iPhone; it carries no name or handle.
struct UniverseShareCard: View {
    enum Mode { case universe, year }

    let snapshot: UniverseSnapshot
    let mode: Mode

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0A0B12), Color(hex: 0x1B1740)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 16) {
                Text(mode == .universe ? "MY UNIVERSE" : "MY YEAR IN CUE")
                    .font(.system(size: 16, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Palette.acc)
                switch mode {
                case .universe:
                    UniverseMap(snapshot: snapshot, animates: false).frame(height: 520)
                    Text("\(snapshot.total) videos shared").font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                case .year:
                    year
                }
                Spacer()
                Text("Made with Cue").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(36)
        }
        .frame(width: 405, height: 720)
    }

    private var year: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("\(snapshot.sharedThisYear)").font(.system(size: 120, weight: .bold)).foregroundStyle(.white)
            Text("videos shared this year").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            if let top = snapshot.platforms.first {
                Label(String(localized: "Most shared to \(top.platform.label)"), systemImage: "paperplane")
                    .font(.system(size: 20)).foregroundStyle(top.platform.tint)
            }
            if let world = snapshot.topics.max(by: { $0.count < $1.count }), world.count > 0 {
                Label(String(localized: "Your busiest world: \(world.topic.label)"), systemImage: "circle.hexagongrid")
                    .font(.system(size: 20)).foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
