//
//  TimelineContentView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Draws the timeline's geometry with layers, only for a window around what shows (zoomed in, a
/// take can be tens of thousands of points wide): the ruler, the cover, the clips with their
/// frames, waveform and badges, the pauses, the track items and their keyframes, the shortcuts on
/// empty tracks, the "+" and the handles. Lives inside the scroll view, so it scrolls with it.
@MainActor
final class TimelineContentView: UIView {
    /// What the clips' frames and waveforms come from.
    struct Sources {
        var take: URL
        var others: [UUID: URL] = [:]
        /// Seconds of the take shown on the cover block.
        var coverTime: TimeInterval = 0.5

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
    private var ghostLayers: [(layer: CALayer, width: CGFloat)] = []
    /// Where the shortcuts are, for tapping.
    private(set) var ghostFrames: [CGRect] = []
    private let layersRoot = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        layer.addSublayer(layersRoot)
        frames.onChange = { [weak self] in self?.redraw() }
        waveforms.onChange = { [weak self] in self?.redraw() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cancelLoading() {
        frames.cancel()
        waveforms.cancel()
    }

    /// New geometry or sources: draws again.
    func show(_ geometry: TimelineGeometry, sources: Sources) {
        let changed = geometry != self.geometry || sources.take != self.sources?.take || sources.others != self.sources?.others
            || sources.coverTime != self.sources?.coverTime
        self.geometry = geometry
        self.sources = sources
        if changed { redraw() }
    }

    /// The scroll view moved: shortcuts follow the left edge, and a new window is drawn when the
    /// visible part nears the edge of the last one.
    func scrolled(to visible: CGRect) {
        self.visible = visible
        layoutGhosts()
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
        layersRoot.sublayers?.forEach { $0.removeFromSuperlayer() }
        ghostLayers = []
        let width = max(visible.width, 320)
        drawn = visible.insetBy(dx: -width, dy: 0)
        drawRuler(geometry)
        drawCover(geometry, sources: sources)
        for clip in geometry.clips where clip.frame.maxX >= drawn.minX && clip.frame.minX <= drawn.maxX {
            drawClip(clip, geometry: geometry, url: sources.url(for: clip.sourceID))
        }
        for pause in geometry.pauses where pause.frame.intersects(drawn) {
            drawPause(pause)
        }
        for join in geometry.joins where join.frame.intersects(drawn) {
            drawJoin(join)
        }
        for item in geometry.items where item.frame.maxX >= drawn.minX - 4 && item.frame.minX <= drawn.maxX {
            drawItem(item)
        }
        for ghost in geometry.ghosts {
            drawGhost(ghost)
        }
        drawAdd(geometry)
        for handle in geometry.handles where handle.frame.intersects(drawn.insetBy(dx: -40, dy: -40)) {
            drawHandle(handle)
        }
        layoutGhosts()
    }

    private func drawRuler(_ geometry: TimelineGeometry) {
        let pps = geometry.pointsPerSecond
        let ticks = TimelineRuler.ticks(
            from: geometry.time(for: drawn.minX), to: geometry.time(for: drawn.maxX),
            duration: geometry.input.duration, pointsPerSecond: pps
        )
        let top: CGFloat = geometry.isCompact ? 4 : 2
        for tick in ticks {
            let x = geometry.x(for: tick.time)
            let line = CALayer()
            line.frame = CGRect(x: x, y: top + 13, width: 1, height: tick.isMajor ? 5 : 3)
            line.backgroundColor = UIColor.white.withAlphaComponent(tick.isMajor ? 0.6 : 0.3).cgColor
            layersRoot.addSublayer(line)
            if let label = tick.label, !geometry.isCompact || tick.isMajor {
                let text = textLayer(label, size: 10, weight: .medium, color: UIColor(Palette.rulerLabel), monospaced: true)
                text.frame.origin = CGPoint(x: x - text.frame.width / 2, y: top)
                layersRoot.addSublayer(text)
            }
        }
    }

    private func drawCover(_ geometry: TimelineGeometry, sources: Sources) {
        let frame = geometry.coverFrame
        guard frame.maxX >= drawn.minX else { return }
        let cover = CALayer()
        cover.frame = frame
        cover.cornerRadius = 8
        cover.masksToBounds = true
        cover.backgroundColor = UIColor(Palette.surface2).cgColor
        let grid = TimelineFrameCache.grids[2]
        if let image = frames.image(for: sources.take, at: sources.coverTime, grid: grid) {
            cover.contents = image.cgImage
            cover.contentsGravity = .resizeAspectFill
        }
        let dim = CALayer()
        dim.frame = cover.bounds
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
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
        layersRoot.addSublayer(cover)
    }

    private func drawClip(_ clip: TimelineGeometry.Clip, geometry: TimelineGeometry, url: URL) {
        let pps = geometry.pointsPerSecond
        let visibleFrame = clip.frame.intersection(drawn.insetBy(dx: -Metrics.clipRadius * 2, dy: -200))
        guard !visibleFrame.isNull, visibleFrame.width > 0 else { return }
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
                if let image = frames.image(for: url, at: sourceTime + tileSeconds / 2, grid: grid) {
                    tile.contents = image.cgImage
                } else {
                    tile.backgroundColor = UIColor(Palette.thumbnailBottom).cgColor
                }
                container.addSublayer(tile)
            }
        }

        // The waveform under the frames.
        let well = CALayer()
        well.frame = CGRect(x: 0, y: clip.thumbnailHeight, width: visibleFrame.width, height: clip.waveformHeight)
        well.backgroundColor = UIColor(Palette.waveformWell).cgColor
        container.addSublayer(well)
        if let levels = waveforms.levels(for: url), !levels.isEmpty {
            let bars = CAShapeLayer()
            bars.fillColor = UIColor(Palette.waveformBar).cgColor
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
            container.borderWidth = 2
            container.borderColor = UIColor(Palette.acc).cgColor
        }
        layersRoot.addSublayer(container)
    }

    private func drawPause(_ pause: TimelineGeometry.Pause) {
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
            dash.path = UIBezierPath(roundedRect: mark.bounds.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 5).cgPath
            dash.fillColor = nil
            dash.strokeColor = UIColor(Palette.pauseKeepBorder).cgColor
            dash.lineWidth = 1.5
            dash.lineDashPattern = [4, 3]
            mark.addSublayer(dash)
        }
        layersRoot.addSublayer(mark)
    }

    /// A cut's mark: "+" on dark for a hard cut, the transition's icon on yellow otherwise.
    private func drawJoin(_ join: TimelineGeometry.Join) {
        let hasTransition = join.transition != .hardCut
        let mark = CALayer()
        mark.frame = join.frame
        mark.cornerRadius = join.frame.width / 2
        mark.backgroundColor = UIColor(hasTransition ? Palette.acc : Palette.joinMark).cgColor
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
        layersRoot.addSublayer(mark)
    }

    private func drawItem(_ item: TimelineGeometry.Item) {
        let style = Self.style(of: item.kind, selected: item.isSelected)
        if item.isSelected {
            let ring = CALayer()
            ring.frame = item.frame.insetBy(dx: -2, dy: -2)
            ring.cornerRadius = Metrics.laneItemRadius + 2
            ring.borderWidth = 2
            ring.borderColor = UIColor(Palette.acc).cgColor
            layersRoot.addSublayer(ring)
        }
        let box = CALayer()
        box.frame = item.frame
        box.cornerRadius = Metrics.laneItemRadius
        box.cornerCurve = .continuous
        box.masksToBounds = true
        box.backgroundColor = style.fill.cgColor
        box.opacity = item.isDimmed ? 0.5 : 1
        // The label stays readable while the item's start is scrolled away.
        let inset = max(0, visible.minX - item.frame.minX)
        var x: CGFloat = 7 + min(inset, max(0, item.frame.width - 60))
        if let icon = symbolLayer(style.symbol, size: 10, color: style.ink) {
            icon.frame.origin = CGPoint(x: x, y: (item.frame.height - icon.frame.height) / 2)
            box.addSublayer(icon)
            x += icon.frame.width + 5
        }
        let label = textLayer(item.label, size: 11.5, weight: .semibold, color: style.ink)
        label.frame = CGRect(x: x, y: (item.frame.height - label.frame.height) / 2, width: max(0, item.frame.width - x - 6), height: label.frame.height)
        box.addSublayer(label)
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
        layersRoot.addSublayer(box)
    }

    private func drawGhost(_ ghost: TimelineGeometry.Ghost) {
        let ink = UIColor(Palette.laneGhostInk)
        let label = textLayer(ghost.label, size: 12, weight: .semibold, color: ink)
        let icon = symbolLayer("plus", size: 10, weight: .bold, color: ink)
        let iconWidth = icon?.frame.width ?? 0
        let width = 9 + iconWidth + 5 + label.frame.width + 12
        let box = CALayer()
        box.frame = CGRect(x: 0, y: ghost.lane.y, width: width, height: ghost.lane.height)
        let border = CAShapeLayer()
        border.path = UIBezierPath(roundedRect: box.bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: Metrics.laneItemRadius).cgPath
        border.fillColor = nil
        border.strokeColor = UIColor(Palette.laneGhostBorder).cgColor
        border.lineWidth = 1
        border.lineDashPattern = [4, 3]
        box.addSublayer(border)
        if let icon {
            icon.frame.origin = CGPoint(x: 9, y: (ghost.lane.height - icon.frame.height) / 2)
            box.addSublayer(icon)
        }
        label.frame.origin = CGPoint(x: 9 + iconWidth + 5, y: (ghost.lane.height - label.frame.height) / 2)
        box.addSublayer(label)
        layersRoot.addSublayer(box)
        ghostLayers.append((box, width))
    }

    /// Shortcuts sit at the start of the video, or 10 pt in from the left edge once it's scrolled
    /// away.
    private func layoutGhosts() {
        guard let geometry else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ghostFrames = zip(geometry.ghosts, ghostLayers).map { ghost, entry in
            let x = max(0, visible.minX + 10)
            let frame = CGRect(x: x, y: ghost.lane.y, width: entry.width, height: ghost.lane.height)
            entry.layer.frame = frame
            return frame
        }
        CATransaction.commit()
    }

    private func drawAdd(_ geometry: TimelineGeometry) {
        let frame = geometry.addFrame
        guard frame.minX <= drawn.maxX else { return }
        let add = CALayer()
        add.frame = frame
        add.cornerRadius = 8
        add.backgroundColor = UIColor.white.cgColor
        if let icon = symbolLayer("plus", size: 14, weight: .bold, color: .black) {
            icon.frame.origin = CGPoint(x: (frame.width - icon.frame.width) / 2, y: (frame.height - icon.frame.height) / 2)
            add.addSublayer(icon)
        }
        layersRoot.addSublayer(add)
    }

    private func drawHandle(_ handle: TimelineGeometry.Handle) {
        let tab = CALayer()
        tab.frame = handle.frame
        tab.backgroundColor = UIColor(Palette.acc).cgColor
        let radius: CGFloat = if case .clip = handle.target { Metrics.clipRadius } else { Metrics.laneItemRadius }
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
        layersRoot.addSublayer(tab)
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

    private func badgeLayer(_ string: String, color: UIColor, weight: UIFont.Weight) -> CALayer {
        let text = textLayer(string, size: 10.5, weight: weight, color: color, monospaced: true)
        let badge = CALayer()
        badge.frame = CGRect(x: 0, y: 0, width: text.frame.width + 12, height: 18)
        badge.cornerRadius = 5
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        text.frame.origin = CGPoint(x: 6, y: (18 - text.frame.height) / 2)
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
        case .text: ItemStyle(fill: UIColor(selected ? Palette.laneTextSelected : Palette.laneText), ink: UIColor(Palette.acc), symbol: "textformat")
        case .media: ItemStyle(fill: UIColor(Palette.laneMedia), ink: UIColor(Palette.laneMediaInk), symbol: "photo")
        case .caption: ItemStyle(fill: UIColor(Palette.laneCaption), ink: .white, symbol: "captions.bubble")
        case .music: ItemStyle(fill: UIColor(Palette.laneMusic), ink: UIColor(Palette.laneMusicInk), symbol: "music.note")
        case .voiceOver: ItemStyle(fill: UIColor(Palette.laneVoiceOver), ink: UIColor(Palette.laneVoiceOverInk), symbol: "mic")
        case .recording: ItemStyle(fill: UIColor(Palette.laneRecording), ink: .white, symbol: "mic.fill")
        }
    }

    private static var hatches: [Bool: UIColor] = [:]

    /// Diagonal stripes: yellow for a pause to remove, gray for one to keep.
    private static func hatch(marked: Bool) -> UIColor {
        if let known = hatches[marked] { return known }
        let stripe = UIColor(marked ? Palette.pauseRemoveStripe : Palette.pauseKeepStripe)
        let gap = UIColor(marked ? Palette.pauseRemoveGap : Palette.pauseKeepGap)
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
