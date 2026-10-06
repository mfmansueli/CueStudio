//
//  TakePipelineCard.swift
//  Cue Studio
//

import SwiftUI

/// The header of the Takes tab (6.2): four nodes on a line, TO PICK › IN EDIT › READY › SHARED, with how many videos are at each stage (tap one
/// to see only those, tap again to see all). The line is grey up to READY and runs green into lilac after it; READY breathes a green ring.
struct TakePipelineCard: View {
    let pipeline: TakePipeline
    let selected: TakeStage?
    let onSelect: (TakeStage) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        ZStack(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: Palette.flightInk.opacity(0.25), location: 0), .init(color: Palette.flightInk.opacity(0.25), location: 0.5),
                    .init(color: Palette.success, location: 0.66), .init(color: Palette.flightLilac, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 2)
            .padding(.horizontal, 44)
            .padding(.top, 25)
            HStack(alignment: .top, spacing: 0) {
                ForEach(TakeStage.allCases) { stage in node(stage) }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 86, alignment: .top)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("takes.pipeline")
    }

    private func node(_ stage: TakeStage) -> some View {
        let count = pipeline.count(of: stage)
        let isOn = selected == stage
        return Button { onSelect(stage) } label: {
            VStack(spacing: 6) {
                circle(stage, count: count, isOn: isOn)
                Text(label(stage, count: count))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.76)
                    .foregroundStyle(isOn ? Palette.accText : labelColor(stage))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(stage.pipelineLabel))
        .accessibilityValue(Text("\(count)"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("takes.stage.\(stage.stepKey)")
    }

    /// "TO PICK", "IN EDIT", "READY"; the shared node carries its count in the name ("3 SHARED"), its disc has the star.
    private func label(_ stage: TakeStage, count: Int) -> String {
        let name = stage.pipelineLabel.uppercased()
        return stage == .shared ? "\(count) \(name)" : name
    }

    private func labelColor(_ stage: TakeStage) -> Color {
        switch stage {
        case .pick: Palette.flightInk.opacity(0.6)
        case .edit: Palette.info
        case .ready: Palette.success
        case .shared: Palette.starLilac
        }
    }

    /// A 28 pt disc: the count in mono, or the star of what is shared.
    private func circle(_ stage: TakeStage, count: Int, isOn: Bool) -> some View {
        ZStack {
            switch stage {
            case .pick:
                disc(fill: Palette.surface2, ring: Palette.flightInk.opacity(0.3), text: "\(count)", ink: .white)
            case .edit:
                disc(fill: Palette.surface2, ring: Palette.info.opacity(0.6), text: "\(count)", ink: Palette.info)
            case .ready:
                readyDisc(count: count)
            case .shared:
                Circle().fill(Palette.takesSharedNode)
                    .overlay(Circle().strokeBorder(Palette.flightLilac, lineWidth: 1))
                    .overlay { Text(verbatim: "✦").font(.system(size: 13)).foregroundStyle(Palette.acc) }
                    .shadow(color: Palette.nightViolet.opacity(0.5), radius: 14)
            }
        }
        .frame(width: 28, height: 28)
        .overlay { if isOn { Circle().strokeBorder(Palette.acc, lineWidth: 1.5).padding(-4) } }
    }

    private func disc(fill: Color, ring: Color, text: String, ink: Color) -> some View {
        Circle().fill(fill)
            .overlay(Circle().strokeBorder(ring, lineWidth: 1))
            .overlay { Text(verbatim: text).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(ink) }
    }

    /// Filled green, black number, and a ring of green that goes out to 6 pt and back every 2 s (`pulse`; still with Reduce Motion).
    private func readyDisc(count: Int) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2
            let eased = 1 - pow(1 - (phase < 0.5 ? phase * 2 : (1 - phase) * 2), 2)
            let spread = reduceMotion ? 0 : 6 * eased
            Circle().fill(Palette.success)
                .overlay { Text(verbatim: "\(count)").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.black) }
                .background {
                    Circle().fill(Palette.success.opacity(reduceMotion ? 0 : 0.5 * (1 - eased)))
                        .frame(width: 28 + spread * 2, height: 28 + spread * 2)
                }
        }
    }
}

extension TakeStage {
    /// The word in identifiers ("takes.stage.ready").
    var stepKey: String {
        switch self {
        case .pick: "pick"
        case .edit: "edit"
        case .ready: "ready"
        case .shared: "shared"
        }
    }
}

#if DEBUG
#Preview {
    let take = Take(
        scriptID: UUID(), scriptTitle: "3 morning habits that changed my life", scriptVersion: 1, number: 1, duration: 62,
        fileName: "x.mov", resolution: .hd1080, frameRate: .fps30, aspect: .portrait, platform: .tiktok
    )
    let videos = [
        TakeVideo(takes: [take], title: take.scriptTitle, platform: .tiktok, stage: .ready),
        TakeVideo(takes: [take], title: "Weekly Q&A", platform: .youtube, stage: .shared),
    ]
    TakePipelineCard(pipeline: TakePipeline(videos: videos), selected: .ready, onSelect: { _ in })
        .padding()
        .background(Palette.bg)
}
#endif
