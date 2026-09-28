//
//  TimelineStripView.swift
//  Cue Studio
//

import SwiftUI

/// The Quick edit timeline: the frames of the edited video, the yellow trim handles, a black
/// hairline between sections (with a red dot where something was removed), the selected section,
/// the red "Remove part" range and the playhead. A bubble above shows the time being set.
///
/// One drag gesture reads every touch and decides what it holds where the finger lands (see
/// `TimelineLayout.target`): the red range's edges while it shows, else a handle trims, the
/// playhead is dragged from where it is, and anywhere else the playhead jumps to the finger and
/// follows it; a tap also selects the section there. Nothing plays while a finger is down. While a
/// handle is dragged the strip keeps its scale, dimming what the handle cuts; it fits the new
/// length when the handle is let go.
struct TimelineStripView: View {
    let viewModel: QuickEditViewModel

    static let bubbleHeight: CGFloat = 30
    static let knobHeight: CGFloat = 16
    static let framesHeight: CGFloat = 80

    @State private var drag: Drag?
    /// Resets when the system cancels the touch, which `onEnded` never hears about.
    @GestureState private var isTouching = false

    private enum Drag {
        /// `origin` is the timeline when the handle was caught: the strip keeps its layout.
        case trim(TrimHandle, fromSource: TimeInterval, origin: EditTimeline)
        case removal(RemovalEdge, grab: CGFloat)
        /// `grab` keeps the playhead where it sat under the finger instead of jumping to it.
        case scrub(grab: CGFloat)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = TimelineLayout(timeline: frozenTimeline ?? viewModel.edit.timeline, width: proxy.size.width)
            let handles = handlePositions(layout)
            ZStack(alignment: .topLeading) {
                TimelineFramesView(
                    videoURL: viewModel.videoURL, layout: layout,
                    frameCount: TimelineLayout.frameCount(width: proxy.size.width, tileWidth: Self.framesHeight * 9 / 16)
                )
                .frame(width: proxy.size.width, height: Self.framesHeight)
                .offset(y: framesTop)
                trimDims(layout, handles: handles)
                seams(layout)
                selection(layout)
                trimBracket(handles)
                removalRange(layout)
                TimelinePlayheadView(
                    viewModel: viewModel, layout: layout, knobHeight: Self.knobHeight, framesHeight: Self.framesHeight,
                    pinnedX: pinnedPlayheadX(handles)
                )
                .offset(y: Self.bubbleHeight)
                bubble(layout, handles: handles)
                handleElement(.start, x: handles.start)
                handleElement(.end, x: handles.end)
                removalEdgeElements(layout)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(dragGesture(layout))
        }
        .frame(height: Self.bubbleHeight + Self.knobHeight + Self.framesHeight + 4)
        .onChange(of: isTouching) { _, touching in
            if !touching { finish() }
        }
    }

    private var framesTop: CGFloat { Self.bubbleHeight + Self.knobHeight }

    /// The timeline the strip is laid out with: the one from before the drag while a handle moves.
    private var frozenTimeline: EditTimeline? {
        if case let .trim(_, _, origin) = drag { return origin }
        return nil
    }

    /// Where the handles are drawn. While one is dragged it moves across the frozen strip by as
    /// much as it has trimmed.
    private func handlePositions(_ layout: TimelineLayout) -> (start: CGFloat, end: CGFloat) {
        guard let origin = frozenTimeline else { return (layout.startHandleX, layout.endHandleX) }
        let timeline = viewModel.edit.timeline
        let start = layout.startHandleX + CGFloat(max(0, timeline.trimStart - origin.trimStart)) * layout.pointsPerSecond
        let end = layout.endHandleX - CGFloat(max(0, origin.trimEnd - timeline.trimEnd)) * layout.pointsPerSecond
        return (start, max(start, end))
    }

    private func pinnedPlayheadX(_ handles: (start: CGFloat, end: CGFloat)) -> CGFloat? {
        guard case let .trim(handle, _, _) = drag else { return nil }
        return handle == .start ? handles.start : handles.end
    }

    // MARK: - Layers

    /// While a handle is dragged: what it is about to cut, darkened.
    @ViewBuilder
    private func trimDims(_ layout: TimelineLayout, handles: (start: CGFloat, end: CGFloat)) -> some View {
        if frozenTimeline != nil {
            Rectangle()
                .fill(Palette.trimDim)
                .frame(width: max(0, handles.start - layout.startHandleX), height: Self.framesHeight)
                .offset(x: layout.startHandleX, y: framesTop)
                .allowsHitTesting(false)
            Rectangle()
                .fill(Palette.trimDim)
                .frame(width: max(0, layout.endHandleX - handles.end), height: Self.framesHeight)
                .offset(x: handles.end, y: framesTop)
                .allowsHitTesting(false)
        }
    }

    /// A black hairline between sections, with a red dot above where the cut removed something.
    private func seams(_ layout: TimelineLayout) -> some View {
        ForEach(1..<max(1, layout.timeline.segments.count), id: \.self) { index in
            let x = layout.piece(index).minX - TimelineLayout.joinWidth / 2
            let removed = !layout.timeline.continuesFromPrevious(index)
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Palette.bg)
                    .frame(width: 3, height: Self.framesHeight)
                    .offset(y: Self.knobHeight)
                if removed {
                    Circle()
                        .fill(Palette.danger)
                        .frame(width: 7, height: 7)
                        .offset(y: Self.knobHeight - 10)
                }
            }
            .frame(width: 7)
            .offset(x: x - 3.5, y: Self.bubbleHeight)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func selection(_ layout: TimelineLayout) -> some View {
        if let index = viewModel.selectedSegmentIndex, layout.timeline.segments.count > 1, frozenTimeline == nil {
            let region = layout.piece(index)
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            shape
                .fill(Palette.selectedSectionFill)
                .overlay(shape.strokeBorder(Palette.ink, lineWidth: 2))
                .frame(width: max(4, region.width), height: Self.framesHeight)
                .offset(x: region.minX, y: framesTop)
                .allowsHitTesting(false)
        }
    }

    /// The yellow frame around what plays, with a handle at each end.
    private func trimBracket(_ handles: (start: CGFloat, end: CGFloat)) -> some View {
        let height = Self.framesHeight + 6
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Rectangle().fill(Palette.acc).frame(height: 3)
                Spacer(minLength: 0)
                Rectangle().fill(Palette.acc).frame(height: 3)
            }
            .frame(width: max(0, handles.end - handles.start), height: height)
            .offset(x: handles.start)
            TrimHandleView(edge: .start, isActive: viewModel.activeHandle == .start)
                .frame(height: height)
                .offset(x: handles.start - TimelineLayout.handleWidth)
            TrimHandleView(edge: .end, isActive: viewModel.activeHandle == .end)
                .frame(height: height)
                .offset(x: handles.end)
        }
        .offset(y: framesTop - 3)
        .allowsHitTesting(false)
    }

    /// "Remove part": the red range and its two edges.
    @ViewBuilder
    private func removalRange(_ layout: TimelineLayout) -> some View {
        if let range = viewModel.removalRange {
            let start = layout.x(forEdited: range.lowerBound)
            let end = layout.x(forEdited: range.upperBound)
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            shape
                .fill(Palette.removalFill)
                .overlay(shape.strokeBorder(Palette.danger, lineWidth: 2))
                .frame(width: max(4, end - start), height: Self.framesHeight + 6)
                .offset(x: start, y: framesTop - 3)
                .allowsHitTesting(false)
            ForEach([start, end], id: \.self) { x in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Palette.danger)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2))
                    .frame(width: 12, height: Self.framesHeight - 24)
                    .offset(x: x - 6, y: framesTop + 12)
                    .allowsHitTesting(false)
            }
        }
    }

    /// The time being set: a handle's place in the recording ("Start 00:02.14"), an edge of the
    /// red range, or the playhead while scrubbing.
    @ViewBuilder
    private func bubble(_ layout: TimelineLayout, handles: (start: CGFloat, end: CGFloat)) -> some View {
        if let content = bubbleContent(layout, handles: handles) {
            Text(content.text)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Palette.acc)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Palette.bg, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.bubbleBorder, lineWidth: 0.5))
                .fixedSize()
                .frame(width: 0)
                .offset(x: min(max(content.x, 44), layout.width - 44))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func bubbleContent(_ layout: TimelineLayout, handles: (start: CGFloat, end: CGFloat)) -> (text: String, x: CGFloat)? {
        let timeline = viewModel.edit.timeline
        switch drag {
        case let .trim(handle, _, _):
            let total = timeline.sourceDuration
            return handle == .start
                ? (String(localized: "Start \(DurationText.timecode(timeline.trimStart, total: total))"), handles.start)
                : (String(localized: "End \(DurationText.timecode(timeline.trimEnd, total: total))"), handles.end)
        case let .removal(edge, _):
            guard let range = viewModel.removalRange else { return nil }
            let time = edge == .start ? range.lowerBound : range.upperBound
            return (DurationText.timecode(time, total: timeline.editedDuration), layout.x(forEdited: time))
        case .scrub:
            let time = viewModel.player.currentTime
            return (DurationText.timecode(time, total: timeline.editedDuration), layout.x(forEdited: time))
        case nil:
            return nil
        }
    }

    /// Where a handle can be caught, for VoiceOver (adjustable) and UI tests. Touches go to the
    /// strip's gesture.
    private func handleElement(_ handle: TrimHandle, x handleX: CGFloat) -> some View {
        let reach = TimelineLayout.handleWidth + 8 + TimelineLayout.handleReach
        let x = handle == .start
            ? handleX - TimelineLayout.handleWidth - 8
            : handleX - TimelineLayout.handleReach
        return Color.clear
            .frame(width: reach, height: Self.framesHeight)
            .offset(x: x, y: framesTop)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(handle == .start ? Text("Start of the edit") : Text("End of the edit"))
            .accessibilityValue(Text(viewModel.handleAccessibilityValue(handle)))
            .accessibilityAdjustableAction { direction in
                viewModel.nudgeTrim(handle, by: direction == .increment ? 0.5 : -0.5)
            }
            .accessibilityIdentifier(handle == .start ? "edit.trimStartHandle" : "edit.trimEndHandle")
    }

    /// The red range's edges, for VoiceOver (adjustable) and UI tests.
    @ViewBuilder
    private func removalEdgeElements(_ layout: TimelineLayout) -> some View {
        if let range = viewModel.removalRange {
            ForEach([RemovalEdge.start, .end], id: \.self) { edge in
                let time = edge == .start ? range.lowerBound : range.upperBound
                Color.clear
                    .frame(width: TimelineLayout.removalEdgeReach * 2, height: Self.framesHeight)
                    .offset(x: layout.x(forEdited: time) - TimelineLayout.removalEdgeReach, y: framesTop)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel(edge == .start ? Text("Start of the part to remove") : Text("End of the part to remove"))
                    .accessibilityValue(Text(DurationText.timecode(time, total: viewModel.edit.editedDuration)))
                    .accessibilityAdjustableAction { direction in
                        viewModel.moveRemovalEdge(edge, toEdited: time + (direction == .increment ? 0.5 : -0.5))
                        viewModel.endScrub()
                    }
                    .accessibilityIdentifier(edge == .start ? "edit.removalStartEdge" : "edit.removalEndEdge")
            }
        }
    }

    // MARK: - Touch

    private func dragGesture(_ layout: TimelineLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                if drag == nil { drag = begin(at: value.startLocation.x, layout: layout) }
                switch drag {
                case let .trim(handle, fromSource, _):
                    let moved = Double(value.translation.width / max(layout.pointsPerSecond, 0.001))
                    viewModel.trim(handle, toSource: fromSource + moved)
                case let .removal(edge, grab):
                    viewModel.moveRemovalEdge(edge, toEdited: layout.editedTime(atX: value.location.x - grab))
                case let .scrub(grab):
                    viewModel.scrub(to: layout.editedTime(atX: value.location.x - grab))
                case nil:
                    break
                }
            }
            .onEnded { value in
                let isTap = abs(value.translation.width) < 6 && abs(value.translation.height) < 6
                if isTap, case .scrub = drag {
                    viewModel.tapTimeline(onPiece: layout.segmentIndex(atX: value.location.x))
                }
                finish()
            }
    }

    private func begin(at x: CGFloat, layout: TimelineLayout) -> Drag {
        let playheadX = layout.x(forEdited: viewModel.player.currentTime)
        switch layout.target(atX: x, playheadX: playheadX, removal: viewModel.removalRange) {
        case .handle(let handle):
            let timeline = viewModel.edit.timeline
            viewModel.beginTrim(handle)
            return .trim(handle, fromSource: handle == .start ? timeline.trimStart : timeline.trimEnd, origin: timeline)
        case .removalEdge(let edge):
            let time = edge == .start ? viewModel.removalRange?.lowerBound : viewModel.removalRange?.upperBound
            return .removal(edge, grab: x - layout.x(forEdited: time ?? 0))
        case .playhead:
            return .scrub(grab: x - playheadX)
        case .timeline:
            return .scrub(grab: 0)
        }
    }

    private func finish() {
        switch drag {
        case .trim: viewModel.endTrim()
        case .scrub, .removal: viewModel.endScrub()
        case nil: break
        }
        drag = nil
    }
}
