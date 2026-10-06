//
//  UniverseShareCard.swift
//  Cue Studio
//

import SwiftUI

/// The 9:16 card "Share my {year} universe" sends (9.2): "MY 2026 UNIVERSE", the map of that year, the count with its main platform and top theme, the
/// @handle and "MADE IN CUE STUDIO". `time` is a second of the 6 s video (the map builds star by star, the count rises); nil is the finished image.
struct UniverseShareCard: View {
    let snapshot: UniverseSnapshot
    let handle: String
    let options: UniverseShareOptions
    var coreColor: CoreColor = .gold
    var time: TimeInterval?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.nightDeep, Palette.nightIndigo], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                Text("MY \(String(snapshot.year)) UNIVERSE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Palette.acc)
                    .padding(.top, 34)
                UniverseMap(
                    snapshot: snapshot, animates: false, coreColor: coreColor, frozenTime: time ?? UniverseShareOptions.buildDuration,
                    buildDuration: UniverseShareOptions.buildDuration, showsCounts: options.showsNumbers
                )
                .frame(height: 330)
                if options.showsNumbers { numbers }
                Spacer(minLength: 0)
                if options.showsHandle, !handle.isEmpty {
                    Text(verbatim: "@\(handle)").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                }
                Text("MADE IN CUE STUDIO")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.inkHint)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: UniverseShareOptions.cardSize.width, height: UniverseShareOptions.cardSize.height)
    }

    /// The count rises to the real one while the map builds.
    private var shownCount: Int {
        guard let time else { return snapshot.total }
        let progress = min(1, max(0, time / UniverseShareOptions.buildDuration))
        return Int((Double(snapshot.total) * (1 - pow(1 - progress, 3))).rounded())
    }

    private var numbers: some View {
        VStack(spacing: 6) {
            Text("\(shownCount)").font(.system(size: 64, weight: .heavy)).foregroundStyle(.white).monospacedDigit()
            Text(subtitle).font(.system(size: 14)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).lineLimit(2)
        }
    }

    /// "videos · TikTok · Morning routines"
    private var subtitle: String {
        var parts = [String(localized: "videos")]
        if let top = snapshot.platforms.first { parts.append(top.platform.label) }
        if let theme = snapshot.topics.max(by: { $0.count < $1.count }), theme.count > 0 { parts.append(theme.topic.label) }
        return parts.joined(separator: " · ")
    }
}
