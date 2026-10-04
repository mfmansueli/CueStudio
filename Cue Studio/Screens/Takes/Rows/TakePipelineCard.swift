//
//  TakePipelineCard.swift
//  Cue Studio
//

import SwiftUI

/// The header of the Takes tab: TO PICK › IN EDIT › READY › SHARED with how many videos are at each
/// stage (tap one to see only those, tap again to see all), and below, what to do next: "NEXT · POST
/// IT · 3 MORNING HABITS ›".
struct TakePipelineCard: View {
    let pipeline: TakePipeline
    let selected: TakeStage?
    let onSelect: (TakeStage) -> Void
    let onNext: (TakePipeline.Next) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(TakeStage.allCases) { stage in
                    cell(stage)
                    if stage != TakeStage.allCases.last {
                        Text("›")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ink3)
                            .frame(width: 12)
                            .accessibilityHidden(true)
                    }
                }
            }
            if let next = pipeline.next {
                nextLine(next)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8))
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("takes.pipeline")
    }

    private func cell(_ stage: TakeStage) -> some View {
        let count = pipeline.count(of: stage)
        let isOn = selected == stage
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button { onSelect(stage) } label: {
            VStack(spacing: 2) {
                Text(count.formatted(.number.precision(.integerLength(2...))))
                    .font(.system(size: 17, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isOn ? Palette.accText : (count > 0 ? Palette.ink : Palette.ink2))
                Text(stage.pipelineLabel)
                    .textCase(.uppercase)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isOn ? Palette.accSoft : Palette.fill.opacity(0.6), in: shape)
            .overlay(shape.strokeBorder(isOn ? Palette.acc.opacity(0.5) : .clear, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(stage.pipelineLabel))
        .accessibilityValue(Text("\(count)"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("takes.stage.\(stage.stepKey)")
    }

    private func nextLine(_ next: TakePipeline.Next) -> some View {
        Button { onNext(next) } label: {
            HStack(spacing: 8) {
                Text("Next").textCase(.uppercase).foregroundStyle(Palette.accText)
                Text((next.stage.nextVerb ?? "") + " · " + next.video.title)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Text("›").foregroundStyle(Palette.ink2)
            }
            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
            .tracking(0.6)
            .padding(.top, 10)
            .padding(.horizontal, 6)
            .frame(minHeight: Metrics.hitTarget)
            .overlay(alignment: .top) {
                Rectangle().fill(Palette.glassBorder).frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(next.stage.nextVerb ?? ""), \(next.video.title)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("takes.next")
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
    TakePipelineCard(pipeline: TakePipeline(videos: videos), selected: .ready, onSelect: { _ in }, onNext: { _ in })
        .padding()
        .background(Palette.bg)
}
#endif
