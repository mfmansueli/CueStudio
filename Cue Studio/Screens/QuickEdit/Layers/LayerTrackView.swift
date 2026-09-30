//
//  LayerTrackView.swift
//  Cue Studio
//

import SwiftUI

/// A thin timeline of the edit for Text, Media, Voice-over and Speed: the sections (a fine line
/// at each cut), the playhead, and a bar for each item where it plays. Touching a bar picks it;
/// dragging it moves it; dragging an end of the picked bar changes when it starts or stops.
/// Anywhere else, the playhead jumps to the finger and follows it. A drag is one undo step.
struct LayerTrackView: View {
    let viewModel: QuickEditViewModel
    let bars: [LayerBar]
    let tint: Color
    var identifier = "edit.layerTrack"
    var height = LayerTrackView.height
    /// The shared timeline's scale (the Trim strip's, zoom and scroll included); nil spreads the
    /// edit evenly across the track.
    var scale: TrackScale?

    static let height: CGFloat = 58
    private static let inset: CGFloat = 8
    /// How close to a picked bar's end a touch grabs that end.
    private static let edgeReach: CGFloat = 16

    @State private var drag: Drag?

    private enum Drag {
        case scrub
        case move(LayerBar, grabbedAt: TimeInterval)
        case resize(LayerBar, LayerEdge)
        /// On a bar, not moved yet: a tap selects it.
        case pending(LayerBar, startX: CGFloat)
    }

    var body: some View {
        drawing.keepsLeftToRight()
    }

    @ViewBuilder
    private var drawing: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let lanes = LayerLanes.lanes(for: bars)
            let laneCount = LayerLanes.count(lanes)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.surface)
                sectionLines(width: width)
                ForEach(bars) { bar in
                    barView(bar, lane: lanes[bar.id] ?? 0, lanes: laneCount, width: width)
                }
                playhead(width: width)
            }
            .contentShape(Rectangle())
            .gesture(gesture(width: width))
            // Zoomed in, bars run on past both sides.
            .clipped()
        }
        .frame(height: height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Drawing

    private func x(for time: TimeInterval, width: CGFloat) -> CGFloat {
        if let scale { return scale.x(for: time) }
        let total = viewModel.edit.editedDuration
        guard total > 0 else { return Self.inset }
        return Self.inset + CGFloat(min(max(0, time), total) / total) * (width - 2 * Self.inset)
    }

    private func time(at x: CGFloat, width: CGFloat) -> TimeInterval {
        if let scale { return scale.time(at: x) }
        let room = max(1, width - 2 * Self.inset)
        let fraction = Double(min(max(0, (x - Self.inset) / room), 1))
        return fraction * viewModel.edit.editedDuration
    }

    private func sectionLines(width: CGFloat) -> some View {
        ForEach(viewModel.cuts, id: \.index) { cut in
            Rectangle()
                .fill(Palette.cutLine)
                .frame(width: 1, height: height - 12)
                .offset(x: x(for: cut.time, width: width) - 0.5, y: 6)
                .allowsHitTesting(false)
        }
    }

    private func barView(_ bar: LayerBar, lane: Int, lanes: Int, width: CGFloat) -> some View {
        let laneHeight = (height - 12 - CGFloat(lanes - 1) * 3) / CGFloat(lanes)
        let minX = x(for: bar.span.start, width: width)
        let maxX = x(for: bar.span.end, width: width)
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return HStack(spacing: 4) {
            if bar.isSelected, bar.canResize { edgeGrip }
            Text(bar.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(bar.isSelected ? Palette.accInk : Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if bar.isSelected, bar.canResize { edgeGrip }
        }
        .padding(.horizontal, 4)
        .frame(width: max(8, maxX - minX), height: laneHeight)
        .background(bar.isSelected ? tint : tint.opacity(0.35), in: shape)
        .overlay(shape.strokeBorder(bar.isSelected ? Palette.ink : tint, lineWidth: bar.isSelected ? 1.5 : 0.5))
        .offset(x: minX, y: 6 + CGFloat(lane) * (laneHeight + 3))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(bar.title))
        .accessibilityValue(Text("\(DurationText.timecode(bar.span.start, total: viewModel.edit.editedDuration)) – \(DurationText.timecode(bar.span.end, total: viewModel.edit.editedDuration))"))
        .accessibilityAddTraits(bar.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { viewModel.selectBar(bar) }
        .accessibilityIdentifier("edit.layer.\(bar.kind.rawValue)")
    }

    private var edgeGrip: some View {
        Capsule()
            .fill(Palette.accInk.opacity(0.55))
            .frame(width: 3, height: 14)
    }

    private func playhead(width: CGFloat) -> some View {
        Rectangle()
            .fill(Palette.ink)
            .frame(width: 2, height: height)
            .shadow(color: Palette.textShadow, radius: 2)
            .offset(x: x(for: viewModel.player.currentTime, width: width) - 1)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text("Playhead"))
            .accessibilityValue(Text(viewModel.timeLabel))
            .accessibilityAdjustableAction { direction in
                viewModel.nudgePlayhead(by: direction == .increment ? 1 : -1)
            }
    }

    // MARK: - Touch

    private func bar(at point: CGPoint, width: CGFloat) -> LayerBar? {
        let time = time(at: point.x, width: width)
        let reach = scale?.seconds(for: 12) ?? Double(12 / max(1, width - 2 * Self.inset)) * viewModel.edit.editedDuration
        let touched = bars.filter { $0.span.start - reach <= time && time <= $0.span.end + reach }
        // The picked one first, then the shortest (it's the hardest to hit).
        return touched.first(where: \.isSelected) ?? touched.min { $0.span.duration < $1.span.duration }
    }

    private func gesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if drag == nil { drag = start(at: value.startLocation, width: width) }
                switch drag {
                case .scrub:
                    viewModel.scrub(to: viewModel.frameSnapped(edited: time(at: value.location.x, width: width)))
                case let .pending(bar, startX):
                    guard abs(value.location.x - startX) > 4 else { return }
                    viewModel.beginChange()
                    drag = .move(bar, grabbedAt: time(at: startX, width: width) - bar.span.start)
                case let .move(bar, grabbedAt):
                    viewModel.moveBar(bar, toStart: time(at: value.location.x, width: width) - grabbedAt)
                case let .resize(bar, edge):
                    viewModel.resizeBar(bar, edge: edge, to: time(at: value.location.x, width: width))
                case nil:
                    break
                }
            }
            .onEnded { _ in
                switch drag {
                case .scrub: viewModel.endScrub()
                case let .pending(bar, _): viewModel.selectBar(bar)
                case .move, .resize: viewModel.endChange()
                case nil: break
                }
                drag = nil
            }
    }

    private func start(at point: CGPoint, width: CGFloat) -> Drag {
        if let selected = bars.first(where: \.isSelected), selected.canResize {
            let startX = x(for: selected.span.start, width: width)
            let endX = x(for: selected.span.end, width: width)
            if abs(point.x - startX) <= Self.edgeReach, abs(point.x - startX) <= abs(point.x - endX) {
                viewModel.beginChange()
                return .resize(selected, .start)
            }
            if abs(point.x - endX) <= Self.edgeReach {
                viewModel.beginChange()
                return .resize(selected, .end)
            }
        }
        if let bar = bar(at: point, width: width) { return .pending(bar, startX: point.x) }
        viewModel.scrub(to: viewModel.frameSnapped(edited: time(at: point.x, width: width)))
        return .scrub
    }
}
