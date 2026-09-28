//
//  TimelineStripView.swift
//  Cue Studio
//

import SwiftUI

/// The Quick edit timeline: the frames of the edit, the yellow trim handles, the hairlines
/// between pieces (red where something was removed), the selected piece and the playhead.
///
/// One drag gesture reads every touch and decides what it holds where the finger lands (see
/// `TimelineLayout.target`): a handle trims, the playhead is dragged from where it is, anywhere
/// else the playhead jumps to the finger and follows it, and a tap also selects the piece there.
/// Nothing plays while a finger is down.
struct TimelineStripView: View {
    let viewModel: QuickEditViewModel

    static let knobHeight: CGFloat = 16
    static let framesHeight: CGFloat = 52

    @State private var drag: Drag?
    /// Resets when the system cancels the touch, which `onEnded` never hears about.
    @GestureState private var isTouching = false

    private enum Drag {
        case trim(TrimHandle, fromSource: TimeInterval)
        /// `grab` keeps the playhead where it sat under the finger instead of jumping to it.
        case scrub(grab: CGFloat)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = TimelineLayout(timeline: viewModel.edit.timeline, width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                TimelineFramesView(
                    videoURL: viewModel.videoURL, layout: layout,
                    frameCount: TimelineLayout.frameCount(width: proxy.size.width, tileWidth: Self.framesHeight * 9 / 16)
                )
                .frame(width: proxy.size.width, height: Self.framesHeight)
                .offset(y: Self.knobHeight)
                seams(layout)
                selection(layout)
                trimBracket(layout)
                TimelinePlayheadView(viewModel: viewModel, layout: layout, knobHeight: Self.knobHeight, framesHeight: Self.framesHeight)
                handleElement(.start, layout: layout)
                handleElement(.end, layout: layout)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(dragGesture(layout))
        }
        .frame(height: Self.knobHeight + Self.framesHeight + 4)
        .onChange(of: isTouching) { _, touching in
            if !touching { finish() }
        }
    }

    // MARK: - Layers

    /// A hairline between pieces; red where the cut removed something.
    private func seams(_ layout: TimelineLayout) -> some View {
        ForEach(1..<max(1, layout.timeline.segments.count), id: \.self) { index in
            let removed = !layout.timeline.continuesFromPrevious(index)
            Rectangle()
                .fill(removed ? Palette.removedSection : Color.clear)
                .frame(width: TimelineLayout.joinWidth, height: Self.framesHeight)
                .offset(x: layout.piece(index).minX - TimelineLayout.joinWidth, y: Self.knobHeight)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func selection(_ layout: TimelineLayout) -> some View {
        if let index = viewModel.selectedSegmentIndex {
            let region = layout.piece(index)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Palette.ink, lineWidth: 2)
                .frame(width: max(4, region.width), height: Self.framesHeight)
                .offset(x: region.minX, y: Self.knobHeight)
                .allowsHitTesting(false)
        }
    }

    /// The yellow frame around what plays, with a handle at each end.
    private func trimBracket(_ layout: TimelineLayout) -> some View {
        let height = Self.framesHeight + 6
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Rectangle().fill(Palette.acc).frame(height: 3)
                Spacer(minLength: 0)
                Rectangle().fill(Palette.acc).frame(height: 3)
            }
            .frame(width: max(0, layout.endHandleX - layout.startHandleX), height: height)
            .offset(x: layout.startHandleX)
            TrimHandleView(edge: .start, isActive: viewModel.activeHandle == .start)
                .frame(height: height)
                .offset(x: layout.startHandleX - TimelineLayout.handleWidth)
            TrimHandleView(edge: .end, isActive: viewModel.activeHandle == .end)
                .frame(height: height)
                .offset(x: layout.endHandleX)
        }
        .offset(y: Self.knobHeight - 3)
        .allowsHitTesting(false)
    }

    /// Where a handle can be caught, for VoiceOver (adjustable) and UI tests. Touches go to the
    /// strip's gesture.
    private func handleElement(_ handle: TrimHandle, layout: TimelineLayout) -> some View {
        let reach = TimelineLayout.handleWidth + 8 + TimelineLayout.handleReach
        let x = handle == .start
            ? layout.startHandleX - TimelineLayout.handleWidth - 8
            : layout.endHandleX - TimelineLayout.handleReach
        return Color.clear
            .frame(width: reach, height: Self.framesHeight)
            .offset(x: x, y: Self.knobHeight)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(handle == .start ? Text("Start of the edit") : Text("End of the edit"))
            .accessibilityValue(Text(viewModel.handleAccessibilityValue(handle)))
            .accessibilityAdjustableAction { direction in
                viewModel.nudgeTrim(handle, by: direction == .increment ? 0.5 : -0.5)
            }
            .accessibilityIdentifier(handle == .start ? "edit.trimStartHandle" : "edit.trimEndHandle")
    }

    // MARK: - Touch

    private func dragGesture(_ layout: TimelineLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                if drag == nil { drag = begin(at: value.startLocation.x, layout: layout) }
                switch drag {
                case let .trim(handle, fromSource):
                    let moved = Double(value.translation.width / max(layout.pointsPerSecond, 0.001))
                    viewModel.trim(handle, toSource: fromSource + moved)
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
        switch layout.target(atX: x, playheadX: playheadX) {
        case .handle(let handle):
            viewModel.beginTrim(handle)
            return .trim(handle, fromSource: handle == .start ? layout.timeline.trimStart : layout.timeline.trimEnd)
        case .playhead:
            return .scrub(grab: x - playheadX)
        case .timeline:
            return .scrub(grab: 0)
        }
    }

    private func finish() {
        switch drag {
        case .trim: viewModel.endTrim()
        case .scrub: viewModel.endScrub()
        case nil: break
        }
        drag = nil
    }
}
