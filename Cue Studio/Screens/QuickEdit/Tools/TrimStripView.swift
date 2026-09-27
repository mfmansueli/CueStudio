//
//  TrimStripView.swift
//  Cue Studio
//

import SwiftUI

/// The timeline: frames of the take, yellow trim handles, split lines, deleted sections hatched in
/// red and the playhead. Tap or drag the strip to move the playhead and select a section.
struct TrimStripView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let duration = max(0.1, viewModel.edit.sourceDuration)
            let x = { (time: TimeInterval) in CGFloat(time / duration) * width }
            let edit = viewModel.edit
            ZStack(alignment: .leading) {
                FilmstripFrames(videoURL: viewModel.videoURL, duration: viewModel.edit.sourceDuration, count: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                ForEach(edit.segments, id: \.span) { segment in
                    let isSelected = viewModel.selectedSegmentStart == segment.span.start
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(segment.isRemoved ? Palette.removedSection : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(isSelected ? Color.white : .clear, lineWidth: 2))
                        .frame(width: x(segment.span.duration))
                        .offset(x: x(segment.span.start))
                        .allowsHitTesting(false)
                }
                Palette.trimDim.frame(width: x(edit.trimStart)).allowsHitTesting(false)
                Palette.trimDim.frame(width: max(0, width - x(edit.trimEnd))).offset(x: x(edit.trimEnd)).allowsHitTesting(false)
                Rectangle()
                    .strokeBorder(Palette.acc, lineWidth: 3)
                    .frame(width: max(0, x(edit.trimEnd) - x(edit.trimStart)), height: proxy.size.height + 6)
                    .offset(x: x(edit.trimStart))
                    .allowsHitTesting(false)
                ForEach(edit.splits.filter { $0 > edit.trimStart && $0 < edit.trimEnd }, id: \.self) { split in
                    Rectangle().fill(Color.white).frame(width: 2, height: proxy.size.height)
                        .offset(x: x(split) - 1)
                        .allowsHitTesting(false)
                }
                handle(isStart: true).offset(x: x(edit.trimStart) - 14)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        viewModel.setTrimStart(Double(value.location.x / width) * duration)
                    })
                handle(isStart: false).offset(x: x(edit.trimEnd))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        viewModel.setTrimEnd(Double(value.location.x / width) * duration)
                    })
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: proxy.size.height + 16)
                    .shadow(color: Palette.textShadow, radius: 2)
                    .offset(x: x(viewModel.playhead) - 1)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                viewModel.movePlayhead(to: Double(min(max(0, value.location.x), width) / width) * duration)
            })
        }
        .frame(height: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Timeline"))
        .accessibilityValue(Text("Playhead \(viewModel.playheadLabel), length \(DurationText.clock(viewModel.edit.editedDuration))"))
        .accessibilityAdjustableAction { direction in
            let step = viewModel.edit.sourceDuration / 20
            viewModel.movePlayhead(to: viewModel.playhead + (direction == .increment ? step : -step))
        }
        .accessibilityIdentifier("edit.timeline")
    }

    private func handle(isStart: Bool) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: isStart ? 8 : 0, bottomLeadingRadius: isStart ? 8 : 0,
            bottomTrailingRadius: isStart ? 0 : 8, topTrailingRadius: isStart ? 0 : 8,
            style: .continuous
        )
        .fill(Palette.acc)
        .overlay(Capsule().fill(Palette.accInk.opacity(0.5)).frame(width: 2, height: 16))
        .frame(width: 14, height: 62)
        .frame(width: 28, height: 62)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}
