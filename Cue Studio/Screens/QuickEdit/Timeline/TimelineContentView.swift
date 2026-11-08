//
//  TimelineContentView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Draws the timeline's geometry with layers, only for a window around what shows (zoomed in, a
/// take can be tens of thousands of points wide): the ruler, the cover, the clips with their
/// frames, waveform and badges, the pauses, the track items and their keyframes, the hints on
/// empty tracks, the "+" and the handles. Lives inside the scroll view, so it scrolls with it. The
/// track strips and their gutter are not here: they stay on screen (`TimelineLaneBackdropView`,
/// `TimelineLaneGutterView`). When the tracks are taller than the timeline they scroll up and down too, and the ruler
/// stays on top, over them.
///
/// Each piece keeps its layer while what it was drawn from is the same (`Piece`): a redraw (another clip picked, a handle
/// moved, a new window while scrolling) builds only the pieces that changed, and a frame arriving fills the tiles still
/// waiting for it in place. A creator's step moves the pieces it touched for a moment (`TimelineChange`, `TimelineMotion`).
@MainActor
final class TimelineContentView: UIView {
    /// What the clips' frames and waveforms come from.
    struct Sources {
        var take: URL
        var others: [UUID: URL] = [:]
        /// Seconds of the take shown on the cover block until the cover is drawn.
        var coverTime: TimeInterval = 0.5
        /// The cover as drawn (`CoverViewModel.coverImage`): what the cover block shows once there is one.
        var coverImage: UIImage?

        func url(for source: UUID?) -> URL { source.flatMap { others[$0] } ?? take }
    }

    private(set) var geometry: TimelineGeometry?
    private var sources: Sources?
    var currentSources: Sources? { sources }
    let frames = TimelineFrameCache()
    let waveforms = TimelineWaveforms()
    /// The part of the content drawn last.
    private var drawn: CGRect = .null
    /// What shows now (scroll bounds, in content points).
    private var visible: CGRect = .zero
    private var ghostLayers: [CALayer] = []
    private let layersRoot = CALayer()
    /// Pieces that went away, while they fade out.
    private let leavingRoot = CALayer()
    /// The line where the playhead or a handle just stuck.
    private let snapRoot = CALayer()
    /// The ruler's ticks, kept at the top of what shows (on black while tracks pass under it).
    private let rulerRoot = CALayer()
    /// What is drawn now, by what it is.
    private var pieces: [PieceKey: Piece] = [:]
    /// The motions the next redraw plays.
    private var pendingChange: TimelineChange?

    /// One drawn thing of the timeline (a tick, the cover, a clip, a pause, a cut, an item, a hint, the "+", a handle).
    private enum PieceKey: Hashable {
        case tick(Int)
        case cover
        case clip(UUID)
        case pause(UUID)
        case join(UUID)
        case gap(UUID)
        case item(TimelineGeometry.ItemKind, UUID)
        case ghost(Int)
        case add
        case handle(Int)

        /// The clip or item it draws (a cut's mark goes with the clip that starts there).
        var subject: UUID? {
            switch self {
            case .clip(let id), .item(_, let id), .join(let id): id
            default: nil
            }
        }
    }

    /// A piece's layer, with what it was drawn from and the frames it still shows a stand-in for.
    private struct Piece {
        let spec: any Equatable
        let layer: CALayer
        var waiting: [WaitingTile]
    }

    /// A tile showing the nearest frame read until its own arrives.
    private struct WaitingTile {
        let layer: CALayer
        let url: URL
        let time: TimeInterval
        let grid: TimeInterval
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        layer.addSublayer(layersRoot)
        layer.addSublayer(leavingRoot)
        layer.addSublayer(snapRoot)
        layer.addSublayer(rulerRoot)
        frames.onChange = { [weak self] in self?.fillWaitingTiles() }
        waveforms.onChange = { [weak self] in self?.redraw() }
        // Colors and text are drawn for the screen's scale and appearance: when they change, everything is drawn again.
        let traits: [UITrait] = [UITraitUserInterfaceStyle.self, UITraitDisplayScale.self, UITraitAccessibilityContrast.self]
        registerForTraitChanges(traits) { (view: TimelineContentView, _: UITraitCollection) in
            view.pieces = [:]
            view.redraw()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cancelLoading() {
        frames.cancel()
        waveforms.cancel()
    }

    /// New geometry or sources: draws again, with the motions of the step that made it.
    func show(_ geometry: TimelineGeometry, sources: Sources, change: TimelineChange = .none) {
        let changed = geometry != self.geometry || sources.take != self.sources?.take || sources.others != self.sources?.others
            || sources.coverTime != self.sources?.coverTime || sources.coverImage !== self.sources?.coverImage
        self.geometry = geometry
        self.sources = sources
        if change != .none, window != nil { pendingChange = change }
        if changed { redraw() }
    }

    /// The playhead or a handle stuck at `time`: a yellow line there, across the tracks, gone in a blink.
    func flashSnap(at time: TimeInterval) {
        guard let geometry else { return }
        let bottom = max(visible.maxY, geometry.contentHeight)
        TimelineMotion.snapLine(
            in: snapRoot, x: geometry.x(for: time), top: geometry.tracksTop, height: bottom - geometry.tracksTop,
            color: UIColor(Palette.acc)
        )
    }

    /// The scroll view moved: shortcuts follow the left edge, and a new window is drawn when the
    /// visible part nears the edge of the last one.
    func scrolled(to visible: CGRect) {
        self.visible = visible
        layoutGhosts()
        layoutRuler()
        let margin = visible.width / 2
        if drawn.isNull || visible.minX < drawn.minX + margin || visible.maxX > drawn.maxX - margin {
            redraw()
        }
    }

    // MARK: - Drawing

    private var scale: CGFloat { max(1, traitCollection.displayScale) }

    func redraw() {
        guard let geometry, let sources else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let previous = pieces
        let width = max(visible.width, 320)
        // A window around what shows across, every track up and down (they scroll that way without drawing again).
        let height = max(visible.maxY, geometry.contentHeight)
        drawn = CGRect(x: visible.minX - width, y: -height, width: visible.width + 2 * width, height: 3 * height)
        var next: [PieceKey: Piece] = [:]
        var order: [CALayer] = []
        var ghosts: [CALayer] = []
        /// Keeps the piece's layer while its spec is the same, else draws it again.
        func place(_ key: PieceKey, _ spec: some Equatable, draw: (inout [WaitingTile]) -> CALayer?) {
            var piece: Piece
            if let old = pieces[key], Self.same(old.spec, spec) {
                piece = old
            } else {
                var waiting: [WaitingTile] = []
                guard let layer = draw(&waiting) else { return }
                piece = Piece(spec: spec, layer: layer, waiting: waiting)
            }
            next[key] = piece
            order.append(piece.layer)
        }
        let top: CGFloat = geometry.isCompact ? 4 : 2
        for tick in Self.ticks(in: drawn, geometry: geometry) {
            let x = geometry.x(for: tick.time)
            let shows = !geometry.isCompact || tick.isMajor
            place(.tick(Int((tick.time * 1000).rounded())), TickSpec(tick: tick, x: x, top: top, showsLabel: shows)) { _ in
                drawTick(tick, x: x, top: top, showsLabel: shows)
            }
        }
        let ruler = order
        order.removeAll()
        if geometry.coverFrame.maxX >= drawn.minX {
            let spec = CoverSpec(
                frame: geometry.coverFrame, take: sources.take, time: sources.coverTime,
                image: sources.coverImage.map(ObjectIdentifier.init)
            )
            place(.cover, spec) { waiting in drawCover(geometry, sources: sources, waiting: &waiting) }
        }
        for clip in geometry.clips where clip.frame.maxX >= drawn.minX && clip.frame.minX <= drawn.maxX {
            let url = sources.url(for: clip.sourceID)
            let visibleFrame = clip.frame.intersection(drawn.insetBy(dx: -Metrics.clipRadius * 2, dy: -200))
            guard !visibleFrame.isNull, visibleFrame.width > 0 else { continue }
            let spec = ClipSpec(
                clip: clip, visibleFrame: visibleFrame, url: url, pointsPerSecond: geometry.pointsPerSecond,
                hasWaveform: waveforms.levels(for: url)?.isEmpty == false,
                badgeEdges: clip.badge != nil || clip.isSelected ? [visible.minX, visible.maxX] : []
            )
            place(.clip(clip.id), spec) { waiting in
                drawClip(clip, visibleFrame: visibleFrame, geometry: geometry, url: url, waiting: &waiting)
            }
        }
        for pause in geometry.pauses where pause.frame.intersects(drawn) {
            place(.pause(pause.id), pause) { _ in drawPause(pause) }
        }
        for join in geometry.joins where join.frame.intersects(drawn) {
            place(.join(join.id), join) { _ in drawJoin(join) }
        }
        for item in geometry.items where item.frame.maxX >= drawn.minX - 4 && item.frame.minX <= drawn.maxX {
            let inset = max(0, visible.minX - item.frame.minX)
            place(.item(item.kind, item.id), ItemSpec(item: item, labelInset: inset)) { waiting in
                drawItem(item, labelInset: inset, pointsPerSecond: geometry.pointsPerSecond, waiting: &waiting)
            }
        }
        for gap in geometry.gaps where gap.frame.intersects(drawn) {
            place(.gap(gap.id), gap) { _ in drawGap(gap) }
        }
        for (index, ghost) in geometry.ghosts.enumerated() {
            place(.ghost(index), ghost) { _ in drawGhost(ghost) }
            if let layer = next[.ghost(index)]?.layer { ghosts.append(layer) }
        }
        if geometry.addFrame.minX <= drawn.maxX {
            place(.add, geometry.addFrame) { _ in drawAdd(geometry.addFrame) }
        }
        for (index, handle) in geometry.handles.enumerated() where handle.frame.intersects(drawn.insetBy(dx: -40, dy: -40)) {
            place(.handle(index), handle) { _ in drawHandle(handle) }
        }
        pieces = next
        if layersRoot.sublayers?.elementsEqual(order, by: ===) != true { layersRoot.sublayers = order }
        if rulerRoot.sublayers?.elementsEqual(ruler, by: ===) != true { rulerRoot.sublayers = ruler }
        ghostLayers = ghosts
        layoutGhosts()
        layoutRuler()
        fillWaitingTiles()
        if let change = pendingChange {
            pendingChange = nil
            play(change, previous: previous, geometry: geometry)
        }
    }

    /// The motions of a creator's step on the pieces just drawn, and on the ones that went (they fade out over the rest).
    private func play(_ change: TimelineChange, previous: [PieceKey: Piece], geometry: TimelineGeometry) {
        for (key, piece) in previous where pieces[key] == nil {
            guard let id = key.subject, change.removed.contains(id) else { continue }
            leavingRoot.addSublayer(piece.layer)
            TimelineMotion.leave(piece.layer)
        }
        let lastClip = geometry.clips.last?.id
        for (key, piece) in pieces {
            let isNew = previous[key]?.layer !== piece.layer
            if let distance = (key == .add ? lastClip : key.subject).flatMap({ change.shifts[$0] }) {
                TimelineMotion.shift(piece.layer, by: distance)
            }
            if let id = key.subject, change.added.contains(id) {
                TimelineMotion.grow(piece.layer)
                continue
            }
            if case .handle = key, change.picked, isNew { TimelineMotion.showHandle(piece.layer) }
            if change.picked, isNew, Self.isPicked(piece) { TimelineMotion.pick(piece.layer) }
            if let lane = change.arrivedLane, Self.lane(of: key, piece) == lane { TimelineMotion.rise(piece.layer) }
        }
        if !change.added.isEmpty { Haptics.soft() }
    }

    /// The piece draws what is picked (a clip or an item).
    private static func isPicked(_ piece: Piece) -> Bool {
        if let item = piece.spec as? ItemSpec { return item.item.isSelected }
        if let clip = piece.spec as? ClipSpec { return clip.clip.isSelected }
        return false
    }

    /// The track a piece sits on, when it is one of a track's own (an item, an empty track's hint).
    private static func lane(of key: PieceKey, _ piece: Piece) -> TimelineLane? {
        if case .item(let kind, _) = key { return kind.lane }
        if let ghost = piece.spec as? TimelineGeometry.Ghost { return ghost.lane.lane }
        return nil
    }

    /// Frames came in: the tiles showing a stand-in take theirs, and stop waiting once it is their own.
    private func fillWaitingTiles() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        for (key, piece) in pieces where !piece.waiting.isEmpty {
            var still: [WaitingTile] = []
            for tile in piece.waiting {
                if let image = frames.image(for: tile.url, at: tile.time, grid: tile.grid) {
                    tile.layer.contents = image.cgImage
                    tile.layer.backgroundColor = nil
                }
                if !frames.hasExactImage(for: tile.url, at: tile.time, grid: tile.grid) { still.append(tile) }
            }
            pieces[key]?.waiting = still
        }
    }

    /// Whether two specs are the same drawing.
    private static func same(_ old: any Equatable, _ new: some Equatable) -> Bool {
        func equal<T: Equatable>(_ new: T) -> Bool { (old as? T) == new }
        return equal(new)
    }

    private static func ticks(in drawn: CGRect, geometry: TimelineGeometry) -> [TimelineRuler.Tick] {
        TimelineRuler.ticks(
            from: geometry.time(for: drawn.minX), to: geometry.time(for: drawn.maxX),
            duration: geometry.input.duration, pointsPerSecond: geometry.pointsPerSecond
        )
    }

    // MARK: - What each piece is drawn from

    private struct TickSpec: Equatable {
        let tick: TimelineRuler.Tick
        let x: CGFloat
        let top: CGFloat
        let showsLabel: Bool
    }

    private struct CoverSpec: Equatable {
        let frame: CGRect
        let take: URL
        let time: TimeInterval
        let image: ObjectIdentifier?
    }

    private struct ClipSpec: Equatable {
        let clip: TimelineGeometry.Clip
        let visibleFrame: CGRect
        let url: URL
        let pointsPerSecond: CGFloat
        let hasWaveform: Bool
        /// The visible part's edges, where the badges sit (only for a clip with badges).
        let badgeEdges: [CGFloat]
    }

    private struct ItemSpec: Equatable {
        let item: TimelineGeometry.Item
        /// How far the item's start is scrolled away: its label keeps clear of it.
        let labelInset: CGFloat
    }

    /// A tick of the ruler, with its "mm:ss" on major ones.
    private func drawTick(_ tick: TimelineRuler.Tick, x: CGFloat, top: CGFloat, showsLabel: Bool) -> CALayer {
        let group = CALayer()
        let line = CALayer()
        line.frame = CGRect(x: x, y: top + 13, width: 1, height: tick.isMajor ? 5 : 3)
        line.backgroundColor = UIColor.white.withAlphaComponent(tick.isMajor ? 0.6 : 0.3).cgColor
        group.addSublayer(line)
        if let label = tick.label, showsLabel {
            let text = textLayer(label, size: 10, weight: .medium, color: UIColor(Palette.Editor.rulerLabel), monospaced: true)
            text.frame.origin = CGPoint(x: x - text.frame.width / 2, y: top)
            group.addSublayer(text)
        }
        return group
    }

    private func drawCover(_ geometry: TimelineGeometry, sources: Sources, waiting: inout [WaitingTile]) -> CALayer {
        let frame = geometry.coverFrame
        let cover = CALayer()
        cover.frame = frame
        cover.cornerRadius = 8
        cover.masksToBounds = true
        cover.backgroundColor = UIColor(Palette.surface2).cgColor
        let grid = TimelineFrameCache.grids[2]
        if let image = sources.coverImage ?? frames.image(for: sources.take, at: sources.coverTime, grid: grid) {
            cover.contents = image.cgImage
        }
        cover.contentsGravity = .resizeAspectFill
        if sources.coverImage == nil, !frames.hasExactImage(for: sources.take, at: sources.coverTime, grid: grid) {
            waiting.append(WaitingTile(layer: cover, url: sources.take, time: sources.coverTime, grid: grid))
        }
        // The label reads on any cover: a dark shade, lighter over a drawn cover so it can be recognized.
        let dim = CALayer()
        dim.frame = cover.bounds
        dim.backgroundColor = UIColor.black.withAlphaComponent(sources.coverImage == nil ? 0.45 : 0.4).cgColor
        cover.addSublayer(dim)
        let label = textLayer(String(localized: "Cover"), size: 10.5, weight: .bold, color: .white)
        let icon = symbolLayer("pencil", size: 12, color: .white)
        let iconHeight = icon?.frame.height ?? 0
        let total = iconHeight + 2 + label.frame.height
        if let icon {
            icon.frame.origin = CGPoint(x: (frame.width - icon.frame.width) / 2, y: (frame.height - total) / 2)
            cover.addSublayer(icon)
        }
        label.frame.origin = CGPoint(x: (frame.width - label.frame.width) / 2, y: (frame.height - total) / 2 + iconHeight + 2)
        cover.addSublayer(label)
        return cover
    }

    /// A frame of a clip turned, mirrored and cropped as the video shows it: the layer turned on its middle (lying on its side,
    /// its bounds swap so it still fills the tile), flipped across, showing the crop's part of the frame as filmed.
    private static func reshape(_ tile: CALayer, as orientation: ClipOrientation) {
        guard !orientation.isIdentity else { return }
        let frame = tile.frame
        if orientation.turnsSideways {
            tile.bounds = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
            tile.position = CGPoint(x: frame.midX, y: frame.midY)
        }
        var transform = CATransform3DMakeRotation(CGFloat(orientation.quarterTurns) * .pi / 2, 0, 0, 1)
        if orientation.isMirrored { transform = CATransform3DConcat(transform, CATransform3DMakeScale(-1, 1, 1)) }
        tile.transform = transform
        if let part = orientation.uprightCrop { tile.contentsRect = part }
    }

    private func drawClip(
        _ clip: TimelineGeometry.Clip, visibleFrame: CGRect, geometry: TimelineGeometry, url: URL, waiting: inout [WaitingTile]
    ) -> CALayer {
        let pps = geometry.pointsPerSecond
        let container = CALayer()
        container.frame = visibleFrame
        container.cornerRadius = Metrics.clipRadius
        container.cornerCurve = .continuous
        container.masksToBounds = true
        container.backgroundColor = UIColor(Palette.surface).cgColor
        container.opacity = clip.isDimmed ? 0.55 : 1
        let originX = visibleFrame.minX
        // Where the clip's recording starts, in content points (its frame starts 1 pt in).
        let clipStartX = clip.frame.minX - 1

        // Frames, aligned to the recording so trimming doesn't slide them.
        let tileWidth = max(4, clip.thumbnailHeight * 9 / 16)
        let tileSeconds = TimeInterval(tileWidth / pps) * clip.speed
        let grid = TimelineFrameCache.grid(forTile: tileSeconds)
        if tileSeconds > 0 {
            var index = (clip.sourceStart / tileSeconds).rounded(.down)
            while index * tileSeconds < clip.sourceEnd {
                let sourceTime = index * tileSeconds
                let x = clipStartX + CGFloat((sourceTime - clip.sourceStart) / clip.speed) * pps
                index += 1
                guard x + tileWidth >= visibleFrame.minX, x <= visibleFrame.maxX else { continue }
                let tile = CALayer()
                tile.frame = CGRect(x: x - originX, y: 0, width: tileWidth, height: clip.thumbnailHeight)
                tile.contentsGravity = .resizeAspectFill
                tile.masksToBounds = true
                Self.reshape(tile, as: clip.orientation)
                let frameTime = sourceTime + tileSeconds / 2
                if let image = frames.image(for: url, at: frameTime, grid: grid) {
                    tile.contents = image.cgImage
                } else {
                    tile.backgroundColor = UIColor(Palette.Takes.thumbnailBottom).cgColor
                }
                if !frames.hasExactImage(for: url, at: frameTime, grid: grid) {
                    waiting.append(WaitingTile(layer: tile, url: url, time: frameTime, grid: grid))
                }
                container.addSublayer(tile)
            }
        }

        // The waveform under the frames.
        let well = CALayer()
        well.frame = CGRect(x: 0, y: clip.thumbnailHeight, width: visibleFrame.width, height: clip.waveformHeight)
        well.backgroundColor = UIColor(Palette.Editor.waveformWell).cgColor
        container.addSublayer(well)
        if let levels = waveforms.levels(for: url), !levels.isEmpty {
            let bars = CAShapeLayer()
            bars.fillColor = UIColor(Palette.Editor.waveformBar).cgColor
            let path = CGMutablePath()
            let stride = pps < 22 ? 4 : pps < 34 ? 2 : 1
            let barWidth = max(1, CGFloat(0.1 / clip.speed) * pps * CGFloat(stride) * 0.55)
            var index = Int((clip.sourceStart * 10).rounded(.up))
            let last = Int((clip.sourceEnd * 10).rounded(.down))
            while index < last {
                defer { index += stride }
                let x = clipStartX + CGFloat((Double(index) / 10 - clip.sourceStart) / clip.speed) * pps
                guard x >= visibleFrame.minX - barWidth, x <= visibleFrame.maxX else { continue }
                let level = CGFloat(levels[min(index, levels.count - 1)])
                let height = max(1.5, level * (clip.waveformHeight - 2))
                path.addRoundedRect(
                    in: CGRect(x: x - originX, y: clip.thumbnailHeight + clip.waveformHeight - 1 - height, width: barWidth, height: height),
                    cornerWidth: min(0.5, barWidth / 2), cornerHeight: 0.5
                )
            }
            bars.path = path
            container.addSublayer(bars)
        }

        // Badges, on the part that shows.
        let left = max(clip.frame.minX, visible.minX) - originX
        if let badge = clip.badge {
            let label = badgeLayer(badge, color: UIColor(Palette.acc), weight: .bold)
            label.frame.origin = CGPoint(x: left + 5, y: 5)
            container.addSublayer(label)
        }
        if clip.isSelected {
            let label = badgeLayer(DurationText.tenths(clip.duration), color: .white, weight: .semibold)
            let right = min(clip.frame.maxX, visible.maxX) - originX
            label.frame.origin = CGPoint(x: right - label.frame.width - 5, y: 5)
            container.addSublayer(label)
            // A picked clip is framed in white; its handles are the yellow part.
            container.borderWidth = 2
            container.borderColor = UIColor.white.cgColor
        }
        return container
    }

    private func drawPause(_ pause: TimelineGeometry.Pause) -> CALayer {
        let mark = CALayer()
        mark.frame = pause.frame
        mark.cornerRadius = 5
        mark.masksToBounds = true
        mark.backgroundColor = Self.hatch(marked: pause.isMarked).cgColor
        if pause.isMarked {
            mark.borderWidth = 2
            mark.borderColor = UIColor(Palette.acc).cgColor
        } else {
            let dash = CAShapeLayer()
            dash.path = UIBezierPath(roundedRect: mark.bounds.insetBy(dx: 0.75, dy: 0.75), cornerRadius: Metrics.editorMarkRadius).cgPath
            dash.fillColor = nil
            dash.strokeColor = UIColor(Palette.Editor.pauseKeepBorder).cgColor
            dash.lineWidth = 1.5
            dash.lineDashPattern = [4, 3]
            mark.addSublayer(dash)
        }
        return mark
    }

    /// A cut's mark: "+" on dark for a hard cut, the transition's icon on yellow otherwise.
    private func drawJoin(_ join: TimelineGeometry.Join) -> CALayer {
        let hasTransition = join.transition != .hardCut
        let mark = CALayer()
        mark.frame = join.frame
        mark.cornerRadius = join.frame.width / 2
        mark.backgroundColor = UIColor(hasTransition ? Palette.acc : Palette.Editor.joinMark).cgColor
        mark.borderWidth = join.isSelected ? 2 : 1
        mark.borderColor = (join.isSelected ? UIColor(Palette.acc) : UIColor.white.withAlphaComponent(0.35)).cgColor
        let ink: UIColor = hasTransition ? .black : .white
        if let icon = symbolLayer(join.transition.systemImage, size: 9, weight: .bold, color: ink) {
            icon.frame.origin = CGPoint(x: (join.frame.width - icon.frame.width) / 2, y: (join.frame.height - icon.frame.height) / 2)
            mark.addSublayer(icon)
        }
        if join.isSelected {
            let ring = CALayer()
            ring.frame = mark.bounds.insetBy(dx: -3, dy: -3)
            ring.cornerRadius = ring.frame.width / 2
            ring.borderWidth = 2
            ring.borderColor = UIColor(Palette.acc).cgColor
            mark.addSublayer(ring)
        }
        return mark
    }

    /// A short space between two supports: a thin yellow mark across the track, the space itself hatched.
    private func drawGap(_ gap: TimelineGeometry.Gap) -> CALayer {
        let layer = CALayer()
        layer.frame = gap.frame
        layer.cornerRadius = Metrics.editorTickRadius
        layer.backgroundColor = Self.hatch(marked: true).cgColor
        layer.borderWidth = 1
        layer.borderColor = UIColor(Palette.acc).cgColor
        return layer
    }

    /// A photo's or video's frames along its bar, piece by piece, each from its second of the file (a picture repeats); where
    /// it doesn't show within its bar (another recording's clip in between), the track shows through, dimmed.
    private func drawStrip(
        _ strip: TimelineGeometry.MediaStrip, in item: TimelineGeometry.Item, pointsPerSecond pps: CGFloat, into box: CALayer,
        waiting: inout [WaitingTile]
    ) {
        let url = EditMediaFiles.url(for: strip.fileName)
        let tileWidth = max(12, item.frame.height * 0.75)
        let tileSeconds = TimeInterval(tileWidth / max(0.001, pps))
        let grid = TimelineFrameCache.grid(forTile: tileSeconds)
        let start = item.frame.minX
        var shownUntil = start
        for piece in strip.pieces {
            let pieceX = CGFloat(piece.edited.start) * pps
            if pieceX - shownUntil > 1 {
                let hidden = CALayer()
                hidden.frame = CGRect(x: shownUntil - start, y: 0, width: pieceX - shownUntil, height: item.frame.height)
                hidden.backgroundColor = UIColor(Palette.Editor.coverDim).cgColor
                box.addSublayer(hidden)
            }
            var x = pieceX
            let pieceEnd = CGFloat(piece.edited.end) * pps
            while x < pieceEnd {
                let tile = CALayer()
                tile.frame = CGRect(x: x - start, y: 0, width: min(tileWidth, pieceEnd - x), height: item.frame.height)
                tile.contentsGravity = .resizeAspectFill
                tile.masksToBounds = true
                let time = strip.isVideo ? piece.fileStart + TimeInterval((x - pieceX) / pps) + tileSeconds / 2 : 0
                if let image = frames.image(for: url, at: time, grid: grid) {
                    tile.contents = image.cgImage
                } else {
                    tile.backgroundColor = UIColor(Palette.Takes.thumbnailBottom).cgColor
                }
                if !frames.hasExactImage(for: url, at: time, grid: grid) {
                    waiting.append(WaitingTile(layer: tile, url: url, time: time, grid: grid))
                }
                box.addSublayer(tile)
                x += tileWidth
            }
            shownUntil = pieceEnd
        }
    }

    private func drawItem(
        _ item: TimelineGeometry.Item, labelInset inset: CGFloat, pointsPerSecond: CGFloat, waiting: inout [WaitingTile]
    ) -> CALayer {
        let style = Self.style(of: item.kind, selected: item.isSelected)
        // The name, the symbol and the corners grow with the track.
        let look = TimelineLaneLook(laneHeight: item.frame.height)
        let group = CALayer()
        group.opacity = Float(item.opacity)
        if item.isSelected {
            let ring = CALayer()
            ring.frame = item.frame.insetBy(dx: -2, dy: -2)
            ring.cornerRadius = look.radius + 2
            ring.borderWidth = 2
            ring.borderColor = UIColor.white.cgColor
            group.addSublayer(ring)
        }
        let box = CALayer()
        box.frame = item.frame
        box.cornerRadius = look.radius
        box.cornerCurve = .continuous
        box.masksToBounds = true
        box.backgroundColor = style.fill.cgColor
        box.opacity = item.isDimmed ? 0.5 : 1
        // The label stays readable while the item's start is scrolled away.
        var x: CGFloat = look.padding + min(inset, max(0, item.frame.width - 60))
        if item.kind == .blur {
            // A Blur area: its name on a dark badge, readable over the orange hatch of what's left unchecked.
            let badge = badgeLayer(item.label, color: .white, weight: .semibold, symbol: style.symbol, look: look)
            badge.frame.origin = CGPoint(x: x - 3, y: (item.frame.height - badge.frame.height) / 2)
            if badge.frame.maxX > item.frame.width - 2 { badge.frame.size.width = max(0, item.frame.width - 2 - badge.frame.minX) }
            box.addSublayer(badge)
        } else if let strip = item.strip {
            // A photo or video: its frames, with its kind and how it shows on a dark badge over them.
            drawStrip(strip, in: item, pointsPerSecond: pointsPerSecond, into: box, waiting: &waiting)
            let symbol = item.isLocked ? "lock.fill" : strip.layout.systemImage
            let badge = badgeLayer(item.label, color: .white, weight: .semibold, symbol: symbol, look: look)
            badge.frame.origin = CGPoint(x: x - 3, y: (item.frame.height - badge.frame.height) / 2)
            if badge.frame.maxX > item.frame.width - 2 { badge.frame.size.width = max(0, item.frame.width - 2 - badge.frame.minX) }
            box.addSublayer(badge)
        } else {
            // A locked item says so where its kind's symbol was.
            if let icon = symbolLayer(item.isLocked ? "lock.fill" : item.symbol ?? style.symbol, size: look.symbolSize, color: style.ink) {
                icon.frame.origin = CGPoint(x: x, y: (item.frame.height - icon.frame.height) / 2)
                box.addSublayer(icon)
                x += icon.frame.width + look.gap
            }
            let label = textLayer(item.label, size: look.labelSize, weight: .semibold, color: style.ink)
            label.frame = CGRect(x: x, y: (item.frame.height - label.frame.height) / 2, width: max(0, item.frame.width - x - 6), height: label.frame.height)
            box.addSublayer(label)
        }
        // A Blur area's stretches left unchecked: hatched over the bar, under its label.
        for range in item.warningRanges {
            let hatch = CALayer()
            hatch.frame = CGRect(x: range.lowerBound, y: 0, width: range.upperBound - range.lowerBound, height: item.frame.height)
            hatch.backgroundColor = Self.unchecked().cgColor
            box.insertSublayer(hatch, at: 0)
        }
        // The music's beats: short ticks along the bottom, in the label's color.
        for offset in item.beatOffsets where offset >= 0 && offset <= item.frame.width {
            let tick = CALayer()
            tick.frame = CGRect(x: offset - 1, y: item.frame.height - 7, width: 2, height: 5)
            tick.cornerRadius = 1
            tick.backgroundColor = style.ink.cgColor
            box.addSublayer(tick)
        }
        for offset in item.keyframeOffsets {
            let diamond = CALayer()
            diamond.bounds = CGRect(x: 0, y: 0, width: 8, height: 8)
            diamond.position = CGPoint(x: offset, y: item.frame.height / 2)
            diamond.backgroundColor = UIColor.white.cgColor
            diamond.borderColor = UIColor.black.cgColor
            diamond.borderWidth = 1.5
            diamond.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 4))
            box.addSublayer(diamond)
        }
        group.addSublayer(box)
        return group
    }

    /// What an empty track says: plain text, since a tap anywhere on the track does the job.
    private func drawGhost(_ ghost: TimelineGeometry.Ghost) -> CALayer {
        let size = TimelineLaneLook(laneHeight: ghost.lane.height).hintSize
        let label = textLayer(ghost.label, size: size, weight: .medium, color: UIColor(Palette.Editor.laneHintInk))
        label.frame.origin = CGPoint(x: 0, y: ghost.lane.y + (ghost.lane.height - label.frame.height) / 2)
        label.opacity = Float(ghost.lane.opacity)
        label.zPosition = 2
        return label
    }

    /// Hints stay at a fixed place on screen, past the gutter, whatever the scroll.
    /// The ruler at the top of what shows, across its width: on black once tracks scroll under it.
    private func layoutRuler() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let height = geometry?.tracksTop ?? 0
        rulerRoot.frame = CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: height)
        rulerRoot.bounds.origin = CGPoint(x: visible.minX, y: 0)
        rulerRoot.backgroundColor = visible.minY > 0.5 ? UIColor.black.cgColor : nil
        CATransaction.commit()
    }

    private func layoutGhosts() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in ghostLayers {
            layer.frame.origin.x = visible.minX + TimelineGeometry.hintLeading
        }
        CATransaction.commit()
    }

    private func drawAdd(_ frame: CGRect) -> CALayer {
        let add = CALayer()
        add.frame = frame
        add.cornerRadius = 8
        add.backgroundColor = UIColor.white.cgColor
        if let icon = symbolLayer("plus", size: 14, weight: .bold, color: .black) {
            icon.frame.origin = CGPoint(x: (frame.width - icon.frame.width) / 2, y: (frame.height - icon.frame.height) / 2)
            add.addSublayer(icon)
        }
        return add
    }

    private func drawHandle(_ handle: TimelineGeometry.Handle) -> CALayer {
        let tab = CALayer()
        tab.frame = handle.frame
        tab.backgroundColor = UIColor(Palette.acc).cgColor
        let radius = if case .clip = handle.target { Metrics.clipRadius } else { TimelineLaneLook(laneHeight: handle.frame.height).radius }
        tab.cornerRadius = radius
        tab.maskedCorners = handle.target.edge == .start
            ? [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        let grip = CALayer()
        grip.bounds = CGRect(x: 0, y: 0, width: 2.5, height: handle.frame.height * 0.42)
        grip.position = CGPoint(x: handle.frame.width / 2, y: handle.frame.height / 2)
        grip.cornerRadius = 1.25
        grip.backgroundColor = UIColor.black.withAlphaComponent(0.55).cgColor
        tab.addSublayer(grip)
        return tab
    }

    // MARK: - Pieces

    private func textLayer(_ string: String, size: CGFloat, weight: UIFont.Weight, color: UIColor, monospaced: Bool = false) -> CATextLayer {
        let font = monospaced ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : UIFont.systemFont(ofSize: size, weight: weight)
        let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let text = CATextLayer()
        // A plain string with the layer's font: an attributed one draws nothing when it has to be
        // cut short, and a long caption on its track has to end with "…".
        text.string = string
        text.font = font
        text.fontSize = size
        text.foregroundColor = color.cgColor
        text.contentsScale = scale
        text.truncationMode = .end
        text.isWrapped = false
        let measured = attributed.size()
        text.frame = CGRect(x: 0, y: 0, width: ceil(measured.width) + 1, height: ceil(measured.height))
        return text
    }

    /// A dark badge on frames: a clip's "1.5×" and length (in mono), or a photo's or video's kind with its layout's symbol, as
    /// large as `look` makes it on a track (on a clip, the size of a 28 pt track's).
    private func badgeLayer(
        _ string: String, color: UIColor, weight: UIFont.Weight, symbol: String? = nil,
        look: TimelineLaneLook = TimelineLaneLook(laneHeight: TimelineLaneLook.base)
    ) -> CALayer {
        let text = textLayer(string, size: look.badgeSize, weight: weight, color: color, monospaced: symbol == nil)
        let height = look.badgeHeight
        let badge = CALayer()
        var x: CGFloat = 6
        if let symbol, let icon = symbolLayer(symbol, size: look.badgeSize - 1, color: color) {
            icon.frame.origin = CGPoint(x: x, y: (height - icon.frame.height) / 2)
            badge.addSublayer(icon)
            x += icon.frame.width + 4
        }
        badge.frame = CGRect(x: 0, y: 0, width: x + text.frame.width + 6, height: height)
        badge.cornerRadius = Metrics.editorMarkRadius
        badge.masksToBounds = true
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        text.frame.origin = CGPoint(x: x, y: (height - text.frame.height) / 2)
        badge.addSublayer(text)
        return badge
    }

    private func symbolLayer(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight = .semibold, color: UIColor) -> CALayer? {
        guard let image = TimelineSymbols.image(name, size: size, weight: weight, color: color, scale: scale) else { return nil }
        let layer = CALayer()
        layer.contents = image
        layer.contentsScale = scale
        layer.frame = CGRect(origin: .zero, size: TimelineSymbols.size(of: image, scale: scale))
        return layer
    }

    private struct ItemStyle {
        let fill: UIColor
        let ink: UIColor
        let symbol: String
    }

    private static func style(of kind: TimelineGeometry.ItemKind, selected: Bool) -> ItemStyle {
        switch kind {
        case .text:
            ItemStyle(
                fill: UIColor(selected ? Palette.Editor.laneTextSelected : Palette.Editor.laneText),
                ink: UIColor(Palette.Editor.laneTextInk), symbol: "textformat"
            )
        case .media: ItemStyle(fill: UIColor(Palette.Editor.laneMedia), ink: UIColor(Palette.Editor.laneMediaInk), symbol: "photo")
        case .caption: ItemStyle(fill: UIColor(Palette.Editor.laneCaption), ink: UIColor(Palette.Editor.laneCaptionInk), symbol: "captions.bubble")
        case .music: ItemStyle(fill: UIColor(Palette.Editor.laneMusic), ink: UIColor(Palette.Editor.laneMusicInk), symbol: "music.note")
        case .voiceOver: ItemStyle(fill: UIColor(Palette.Editor.laneVoiceOver), ink: UIColor(Palette.Editor.laneVoiceOverInk), symbol: "mic")
        case .recording: ItemStyle(fill: UIColor(Palette.Editor.laneRecording), ink: .white, symbol: "mic.fill")
        case .blur: ItemStyle(fill: UIColor(Palette.Editor.laneBlur), ink: UIColor(Palette.Editor.laneBlurInk), symbol: "eye.slash")
        }
    }

    private static var uncheckedHatch: UIColor?

    /// Orange diagonal stripes: where a Blur area may not cover what it hides.
    private static func unchecked() -> UIColor {
        if let uncheckedHatch { return uncheckedHatch }
        let side: CGFloat = 6 * 2.squareRoot()
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            UIColor(Palette.Editor.blurUncheckedGap).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor(Palette.Editor.blurUncheckedStripe).setStroke()
            let path = UIBezierPath()
            path.lineWidth = 2.5
            for offset in [-side, 0, side] {
                path.move(to: CGPoint(x: offset, y: side))
                path.addLine(to: CGPoint(x: offset + side, y: 0))
            }
            path.stroke()
        }
        let color = UIColor(patternImage: image)
        uncheckedHatch = color
        return color
    }

    private static var hatches: [Bool: UIColor] = [:]

    /// Diagonal stripes: yellow for a pause to remove, gray for one to keep.
    private static func hatch(marked: Bool) -> UIColor {
        if let known = hatches[marked] { return known }
        let stripe = UIColor(marked ? Palette.Editor.pauseRemoveStripe : Palette.Editor.pauseKeepStripe)
        let gap = UIColor(marked ? Palette.Editor.pauseRemoveGap : Palette.Editor.pauseKeepGap)
        let side: CGFloat = 7 * 2.squareRoot()
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            gap.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            stripe.setStroke()
            let path = UIBezierPath()
            path.lineWidth = 3
            for offset in [-side, 0, side] {
                path.move(to: CGPoint(x: offset, y: side))
                path.addLine(to: CGPoint(x: offset + side, y: 0))
            }
            path.stroke()
        }
        let color = UIColor(patternImage: image)
        hatches[marked] = color
        return color
    }
}
