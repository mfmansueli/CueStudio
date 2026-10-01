//
//  TimelineScrollingView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The timeline with the playhead fixed in the middle: the content scrolls under a white line,
/// with the scroll view's own inertia, and the time under the line is `contentOffset` over the
/// points per second. While the video plays the player moves the content; while a finger does,
/// the content scrubs the player (and sticks to cuts, captions, texts and keyframes within 6 pt,
/// with a tick). A pinch zooms around the playhead (ctrl or ⌘ + scroll too). Touches go, in
/// order: a handle, a tap (less than 4 pt) that picks or lets go, a scrub, a pinch.
@MainActor
final class TimelineScrollingView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    /// What the timeline asks of the editor.
    struct Actions {
        var scrub: (TimeInterval) -> Void = { _ in }
        var endScrub: () -> Void = {}
        var tap: (TimelineGeometry.Hit?) -> Void = { _ in }
        var beginHandle: (TimelineGeometry.HandleTarget, [TimeInterval]) -> Void = { _, _ in }
        /// The edge moved by these edited seconds; returns the bubble and the content's shift.
        var moveHandle: (TimeInterval) -> (label: String, compensation: TimeInterval) = { _ in ("", 0) }
        var endHandle: () -> Void = {}
        var zoom: (CGFloat) -> Void = { _ in }
        /// VoiceOver.
        var nudge: (TimeInterval) -> Void = { _ in }
        var selectClipAtPlayhead: () -> Void = {}
        /// VoiceOver: the transition of the cut nearest to the playhead.
        var pickNearestCut: () -> Void = {}
        var accessibilityValue: () -> String = { "" }
    }

    var actions = Actions()

    private let scrollView = UIScrollView()
    private let content = TimelineContentView()
    private let playhead = UIView()
    private let bubble = PaddedLabel()
    private var input: TimelineGeometry.Input?
    private var geometry: TimelineGeometry?
    /// The time under the playhead, as the timeline shows it.
    private var time: TimeInterval = 0
    /// A finger (or the inertia after it) is moving the content.
    private var isScrubbing = false
    /// Setting `contentOffset` from code: not a scrub.
    private var isApplyingOffset = false
    private var lastSnap: TimeInterval?
    /// The handle being dragged, the time it froze the playhead at, and the content's shift.
    private var handle: (target: TimelineGeometry.HandleTarget, time: TimeInterval, compensation: TimeInterval)?
    private var touchDown: CGPoint?
    private var pinchStart: (zoom: CGFloat, time: TimeInterval)?
    private var zoom: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .normal
        scrollView.clipsToBounds = true
        scrollView.addSubview(content)
        addSubview(scrollView)

        playhead.backgroundColor = .white
        playhead.layer.cornerRadius = 1
        playhead.layer.shadowColor = UIColor.black.cgColor
        playhead.layer.shadowOpacity = 0.6
        playhead.layer.shadowRadius = 3
        playhead.layer.shadowOffset = .zero
        playhead.isUserInteractionEnabled = false
        addSubview(playhead)

        bubble.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        bubble.textColor = .black
        bubble.backgroundColor = UIColor(Palette.acc)
        bubble.layer.cornerRadius = 10
        bubble.layer.masksToBounds = true
        bubble.isHidden = true
        bubble.isUserInteractionEnabled = false
        addSubview(bubble)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        scrollView.addGestureRecognizer(tap)

        let handlePan = UIPanGestureRecognizer(target: self, action: #selector(handlePanned(_:)))
        handlePan.delegate = self
        handlePan.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(handlePan)
        scrollView.panGestureRecognizer.require(toFail: handlePan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        // Ctrl (or ⌘) + scroll zooms, like a pinch, on a Mac or the Simulator.
        let zoomScroll = UIPanGestureRecognizer(target: self, action: #selector(zoomScrolled(_:)))
        zoomScroll.allowedScrollTypesMask = .all
        zoomScroll.allowedTouchTypes = []
        zoomScroll.delegate = self
        addGestureRecognizer(zoomScroll)
        scrollView.panGestureRecognizer.require(toFail: zoomScroll)

        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        accessibilityIdentifier = "edit.timeline"
        accessibilityLabel = String(localized: "Timeline")
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: String(localized: "Select this clip")) { [weak self] _ in
                self?.actions.selectClipAtPlayhead()
                return true
            },
            UIAccessibilityCustomAction(name: String(localized: "Transition at the nearest cut")) { [weak self] _ in
                self?.actions.pickNearestCut()
                return true
            },
            UIAccessibilityCustomAction(name: String(localized: "Zoom in")) { [weak self] _ in
                self?.zoomStep(by: 1.6)
                return true
            },
            UIAccessibilityCustomAction(name: String(localized: "Zoom out")) { [weak self] _ in
                self?.zoomStep(by: 1 / 1.6)
                return true
            },
        ]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cancelLoading() {
        content.cancelLoading()
    }

    // MARK: - Updates from the editor

    /// New contents (an edit, a selection, a panel, a zoom).
    func update(input: TimelineGeometry.Input, sources: TimelineContentView.Sources) {
        guard input != self.input || content.geometry == nil else {
            content.show(geometry ?? TimelineGeometry(input), sources: sources)
            return
        }
        self.input = input
        // A pinch in progress keeps its own zoom until it ends.
        var shown = input
        if pinchStart != nil { shown.pointsPerSecond = TimelineGeometry.basePointsPerSecond * zoom }
        zoom = shown.pointsPerSecond / TimelineGeometry.basePointsPerSecond
        apply(TimelineGeometry(shown), sources: sources)
    }

    /// The player's clock: followed unless a finger is moving the content or holding a handle.
    func show(time: TimeInterval) {
        guard !isScrubbing, handle == nil, pinchStart == nil else { return }
        guard abs(time - self.time) > 0.000_1 || scrollView.contentOffset.x != offset(for: time) else { return }
        self.time = time
        setOffset(for: time)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        let half = bounds.width / 2
        if scrollView.contentInset.left != half {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: half, bottom: 0, right: half)
        }
        content.frame = CGRect(x: 0, y: 0, width: geometry?.contentWidth ?? 0, height: bounds.height)
        scrollView.contentSize = CGSize(width: geometry?.contentWidth ?? 0, height: bounds.height)
        let top: CGFloat = geometry?.isCompact == true ? 16 : 14
        playhead.frame = CGRect(x: half - 1, y: top, width: 2, height: max(0, bounds.height - top))
        layoutBubble()
        setOffset(for: displayedTime)
    }

    private func apply(_ geometry: TimelineGeometry, sources: TimelineContentView.Sources) {
        self.geometry = geometry
        content.frame = CGRect(x: 0, y: 0, width: geometry.contentWidth, height: bounds.height)
        scrollView.contentSize = CGSize(width: geometry.contentWidth, height: bounds.height)
        content.show(geometry, sources: sources)
        setOffset(for: displayedTime)
        setNeedsLayout()
    }

    /// The time the content is drawn at: the playhead's, shifted while a clip's left handle is
    /// held so its frames stay under the finger.
    private var displayedTime: TimeInterval {
        if let handle { return handle.time + handle.compensation }
        return time
    }

    private var pointsPerSecond: CGFloat { geometry?.pointsPerSecond ?? TimelineGeometry.basePointsPerSecond }

    private func offset(for time: TimeInterval) -> CGFloat {
        CGFloat(time) * pointsPerSecond - bounds.width / 2
    }

    private func setOffset(for time: TimeInterval) {
        isApplyingOffset = true
        scrollView.contentOffset = CGPoint(x: offset(for: time), y: 0)
        isApplyingOffset = false
        content.scrolled(to: CGRect(origin: scrollView.contentOffset, size: bounds.size))
    }

    private func layoutBubble() {
        let size = bubble.intrinsicContentSize
        bubble.frame = CGRect(x: bounds.width / 2 + 1 - size.width / 2, y: 0, width: size.width, height: 20)
    }

    // MARK: - Scrolling

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrubbing = true
        lastSnap = nil
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        content.scrolled(to: CGRect(origin: scrollView.contentOffset, size: bounds.size))
        guard !isApplyingOffset, isScrubbing, let geometry else { return }
        let duration = geometry.input.duration
        var time = min(max(0, TimeInterval((scrollView.contentOffset.x + bounds.width / 2) / pointsPerSecond)), duration)
        if scrollView.isTracking, let snap = TimelineSnapping.snapped(time, to: geometry.snapTimes, pointsPerSecond: pointsPerSecond) {
            if lastSnap.map({ abs($0 - snap) > 0.000_1 }) ?? true { Haptics.snap() }
            lastSnap = snap
            time = snap
            setOffset(for: snap)
        } else {
            lastSnap = nil
        }
        self.time = time
        actions.scrub(time)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { endScrub() }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        endScrub()
    }

    private func endScrub() {
        guard isScrubbing else { return }
        isScrubbing = false
        actions.endScrub()
    }

    // MARK: - Gestures

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer, gestureRecognizer.view === scrollView {
            touchDown = touch.location(in: content)
        }
        return true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return super.gestureRecognizerShouldBegin(gestureRecognizer) }
        if pan.view === scrollView, pan !== scrollView.panGestureRecognizer {
            // A handle's pan only starts on a handle.
            guard let point = touchDown, let geometry else { return false }
            return geometry.handle(at: point) != nil
        }
        if pan.allowedTouchTypes.isEmpty {
            return pan.modifierFlags.contains(.control) || pan.modifierFlags.contains(.command)
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard let geometry else { return }
        let point = recognizer.location(in: content)
        // A tap on a handle does nothing (the handle is for dragging).
        guard geometry.handle(at: point) == nil else { return }
        actions.tap(geometry.hit(at: point, ghostFrames: content.ghostFrames))
    }

    @objc private func handlePanned(_ recognizer: UIPanGestureRecognizer) {
        guard let geometry else { return }
        switch recognizer.state {
        case .began:
            guard let point = touchDown, let found = geometry.handle(at: point) else { return }
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)
            handle = (found.target, time, 0)
            actions.beginHandle(found.target, geometry.snapTimes)
            Haptics.selection()
        case .changed:
            guard var held = handle else { return }
            let offset = TimeInterval(recognizer.translation(in: self).x / pointsPerSecond)
            let result = actions.moveHandle(offset)
            held.compensation = result.compensation
            handle = held
            bubble.text = result.label
            bubble.isHidden = result.label.isEmpty
            layoutBubble()
            setOffset(for: displayedTime)
        default:
            guard handle != nil else { return }
            handle = nil
            bubble.isHidden = true
            actions.endHandle()
            setOffset(for: time)
        }
    }

    @objc private func pinched(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)
            endScrub()
            pinchStart = (zoom, time)
        case .changed:
            guard let start = pinchStart else { return }
            setZoom(start.zoom * recognizer.scale, keeping: start.time)
        default:
            pinchStart = nil
        }
    }

    @objc private func zoomScrolled(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pinchStart = (zoom, time)
        case .changed:
            guard let start = pinchStart else { return }
            setZoom(start.zoom * exp(-recognizer.translation(in: self).y * 0.01), keeping: start.time)
        default:
            pinchStart = nil
        }
    }

    private func zoomStep(by factor: CGFloat) {
        setZoom(zoom * factor, keeping: time)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Zoom \(Double(zoom).formatted(.number.precision(.fractionLength(1)).locale(.interface)))×"))
    }

    /// Zooms to `value`, the time under the playhead staying put.
    private func setZoom(_ value: CGFloat, keeping time: TimeInterval) {
        guard var input else { return }
        let clamped = min(max(value, TimelineGeometry.zoomRange.lowerBound), TimelineGeometry.zoomRange.upperBound)
        guard abs(clamped - zoom) > 0.000_1 else { return }
        zoom = clamped
        input.pointsPerSecond = TimelineGeometry.basePointsPerSecond * clamped
        self.input = input
        self.time = time
        let geometry = TimelineGeometry(input)
        self.geometry = geometry
        content.frame = CGRect(x: 0, y: 0, width: geometry.contentWidth, height: bounds.height)
        scrollView.contentSize = CGSize(width: geometry.contentWidth, height: bounds.height)
        setOffset(for: time)
        content.show(geometry, sources: currentSources)
        actions.zoom(clamped)
    }

    private var currentSources: TimelineContentView.Sources {
        content.currentSources ?? TimelineContentView.Sources(take: URL(fileURLWithPath: "/"))
    }

    // MARK: - Accessibility

    override var accessibilityValue: String? {
        get { actions.accessibilityValue() }
        set { _ = newValue }
    }

    override func accessibilityIncrement() {
        actions.nudge(0.1)
    }

    override func accessibilityDecrement() {
        actions.nudge(-0.1)
    }
}
