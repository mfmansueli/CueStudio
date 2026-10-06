//
//  ReviewInfoPanel.swift
//  Cue Studio
//

import SwiftUI

/// What a take is (6.3), on the video with no card around it: a dot and the title in 19 pt, the mono line
/// "● TIKTOK · 1080P · 9:16 · ✓ FITS · FROM SCRIPT V1" and the pipeline (PICK · EDIT · READY · SHARED ✦) as four bars.
struct ReviewInfoPanel: View {
    let take: Take
    let stage: TakeStage
    let lengthFit: LengthFit?
    let scriptVersion: String?
    /// The colour of the take's theme, for the dot before the title.
    var dotColor: Color = Palette.World.warm

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            metaLine
            stageBar.padding(.top, 6)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .shadow(color: dotColor.opacity(0.7), radius: 4)
                .accessibilityHidden(true)
            Text(take.scriptTitle)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if take.isEdited {
                Text("Edited")
                    .textCase(.uppercase)
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Palette.infoText)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Palette.infoSoft, in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    /// "● TIKTOK · 1080P · 9:16 · ✓ FITS · FROM SCRIPT V1"
    private var metaLine: some View {
        var line = AttributedString()
        func add(_ text: String, _ color: Color) {
            var run = AttributedString(text)
            run.foregroundColor = color
            line.append(run)
        }
        let platform = take.platform?.label ?? String(localized: "Freestyle")
        add("● ", take.platform?.tint ?? Palette.Platform.neutral)
        add([platform, take.resolution.label, take.aspect.label].map { $0.uppercased() }.joined(separator: " · "), Palette.ink2)
        if let lengthFit {
            add(" · ", Palette.ink2)
            add(Self.fitText(lengthFit), lengthFit.fits ? Palette.successText : Palette.warnText)
        }
        if let scriptVersion {
            add(" · " + String(localized: "FROM SCRIPT \(scriptVersion.uppercased())"), Palette.ink2)
        }
        return Text(line)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityIdentifier("review.lengthFit")
    }

    /// "✓ FITS", or how far off it is.
    static func fitText(_ fit: LengthFit) -> String {
        switch fit.verdict {
        case .fits: String(localized: "✓ FITS")
        case .under(let gap): String(localized: "\(DurationText.remaining(gap).uppercased()) UNDER")
        case .over(let gap): String(localized: "\(DurationText.remaining(gap).uppercased()) OVER")
        }
    }

    private var stageBar: some View {
        let labels = TakeStage.allCases.map { $0 == .shared ? "\($0.stepLabel.uppercased()) ✦" : $0.stepLabel.uppercased() }
        return HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let isDone = index < stage.rawValue
                VStack(spacing: 6) {
                    Capsule()
                        .fill(index == stage.rawValue ? stage.pillTint : (isDone ? Color.white.opacity(0.85) : Palette.fill))
                        .frame(height: 3)
                    Text(label)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(index == stage.rawValue ? stage.pillTint : Palette.inkHint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stage"))
        .accessibilityValue(Text(labels.indices.contains(stage.rawValue) ? labels[stage.rawValue] : ""))
        .accessibilityIdentifier("review.stageBar")
    }
}
