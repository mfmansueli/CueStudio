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
///
/// Collapsed, the video track and the current track show; ▾ beside its icon brings every track out (`TimelineTrackChoice`).
/// A finger dragging the timeline up or down (clearly more than across, not on a handle or the picked item) does it too: the
/// timeline grows or shrinks under the finger as the tracks come out or go away (`TimelineGeometry.Input.reveal`, the editor
/// giving it the height, `EditorLayout.timelineReveal`), and let go it settles with a spring on the nearer state, or the one it
/// was thrown toward (`TimelineRevealSpring`); ▾ settles the same way. The editor makes the timeline tall enough for the
/// tracks it shows; when they still don't fit (a panel open, a very short window) they scroll up and down under the ruler, a
/// fade at the bottom says there are more, and the picked item's track (or the one whose tools are open) comes into sight by
/// itself. Scrolling up and down never scrubs.
@MainActor
final class TimelineScrollingView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    /// What the timeline asks of the editor.
    struct Actions {
        var scrub: (TimeInterval) -> Void = { _ in }
        var endScrub: () -> Void = {}
        var tap: (TimelineGeometry.Hit?) -> Void = { _ in }
        var beginHandle: (TimelineGeometry.HandleTarget, [TimeInterval]) -> Void = { _, _ in }
        /// The edge moved by these edited seconds; returns the bubble, the content's shift and the time it stuck to, if any.
        var moveHandle: (TimeInterval) -> (label: String, compensation: TimeInterval, snap: TimeInterval?) = { _ in ("", 0, nil) }
        var endHandle: () -> Void = {}
        /// A clip held still: Reorder opens (CapCut's long-press).
        var holdClip: (UUID) -> Void = { _ in }
        var zoom: (CGFloat) -> Void = { _ in }
        /// VoiceOver.
        var nudge: (TimeInterval) -> Void = { _ in }
        var selectClipAtPlayhead: () -> Void = {}
        /// VoiceOver: the transition of the cut nearest to the playhead.
        var pickNearestCut: () -> Void = {}
        /// VoiceOver: the playhead to the next cut (true) or the one before.
        var jumpToCut: (Bool) -> Void = { _ in }
        var accessibilityValue: () -> String = { "" }
        /// A finger dragging the timeline up or down, or ▾ settling: how far out every track is (nil once it rests).
        var reveal: (CGFloat?) -> Void = { _ in }
        /// Every track out, or the current one alone: a drag let go, or ▾ (the timeline then settles there by itself).
        var expandTracks: (Bool) -> Void = { _ in }
    }

    var actions = Actions()
    /// What the timeline grows by from the current track alone to every track out (`EditorLayout`): how far a finger drags it
    /// for every track to come out.
    var revealSpan: CGFloat = 0

    private let backdrop = TimelineLaneBackdropView()
    private let scrollView = UIScrollView()
    private let content = TimelineContentView()
    private let gutter = TimelineLaneGutterView()
    private let playhead = UIView()
    private let bubble = PaddedLabel()
    /// Over the bottom edge while tracks are hidden under it.
    private let fade = UIView()
    private let fadeGradient = CAGradientLayer()
    private var input: TimelineGeometry.Input?
    private var geometry: TimelineGeometry?
    /// The time under the playhead, as the timeline shows it.
    private var time: TimeInterval = 0
    /// A finger (or the inertia after it) is moving the content.
    private var isScrubbing = false
    /// Where the content was across when the finger took it, and whether it has moved across since (a drag up or down doesn't
    /// scrub).
    private var dragStartX: CGFloat = 0
    /// Where the finger has taken the content across during a drag, whatever snapping did to the offset, and the offset it
    /// last left (`scrollViewDidScroll`).
    private var fingerX: CGFloat = 0
    private var lastOffsetX: CGFloat = 0
    private var hasScrubbed = false
    /// The track kept in sight last, and the scroll easing to it.
    private var shownLane: TimelineLane?
    private var trackScroll: (from: CGFloat, to: CGFloat, start: CFTimeInterval)?
    private var trackLink: CADisplayLink?
    /// Where the finger came down, on the timeline itself (not the scrolled content).
    private var touchDownOnScreen: CGPoint?
    /// Setting `contentOffset` from code: not a scrub.
    private var isApplyingOffset = false
    private var lastSnap: TimeInterval?
    /// Where the held handle stuck last (its yellow line shows once per stick).
    private var lastHandleSnap: TimeInterval?
    /// A finger on the current track's square: it sinks until the finger lifts.
    private var press: UILongPressGestureRecognizer?
    /// A finger dragging the timeline up or down, and where the tracks were when it took them.
    private var revealPan: UIPanGestureRecognizer?
    private var revealStart: CGFloat?
    /// Settling after the finger let go (or ▾), and the display link stepping it.
    private var revealSettle: (spring: TimelineRevealSpring, start: CFTimeInterval)?
    private var revealLink: CADisplayLink?
    /// A tap with every track out was handed to the editor, the tracks held out: if it put them away they go on the spring.
    private var awaitsTapResult = false
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
        // Across is time, up and down the tracks: a drag goes one way.
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .normal
        scrollView.clipsToBounds = true
        scrollView.addSubview(content)
        addSubview(backdrop)
        addSubview(scrollView)
        addSubview(gutter)
        backdrop.clipsToBounds = true
        gutter.clipsToBounds = true

        fadeGradient.colors = [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.9).cgColor]
        fade.layer.addSublayer(fadeGradient)
        fade.isUserInteractionEnabled = false
        fade.isHidden = true
        addSubview(fade)

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

        let revealPan = UIPanGestureRecognizer(target: self, action: #selector(revealPanned(_:)))
        revealPan.delegate = self
        revealPan.maximumNumberOfTouches = 1
        scrollView.addGestureRecognizer(revealPan)
        scrollView.panGestureRecognizer.require(toFail: revealPan)
        self.revealPan = revealPan

        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = 0.45
        hold.delegate = self
        scrollView.addGestureRecognizer(hold)

        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        press.minimumPressDuration = 0
        press.cancelsTouchesInView = false
        press.delaysTouchesEnded = false
        press.delegate = self
        addGestureRecognizer(press)
        self.press = press

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
            UIAccessibilityCustomAction(name: String(localized: "Next cut")) { [weak self] _ in
                self?.actions.jumpToCut(true)
                return true
            },
            UIAccessibilityCustomAction(name: String(localized: "Previous cut")) { [weak self] _ in
                self?.actions.jumpToCut(false)
                return true
            },
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
        stopTrackScroll()
        stopRevealLink()
        // Going away mid-drag: the editor rests too, after this update.
        if input?.reveal != nil {
            let reveal = actions.reveal
            Task { @MainActor in reveal(nil) }
        }
    }

    // MARK: - Updates from the editor

    /// New contents (an edit, a selection, a panel, a zoom).
    func update(input: TimelineGeometry.Input, sources: TimelineContentView.Sources) {
        var input = input
        if awaitsTapResult {
            awaitsTapResult = false
            if input.tracks?.isExpanded == false, !input.panelIsOpen, let held = input.reveal {
                spring(toExpanded: false, from: held, velocity: 0)
            } else if input.reveal != nil, revealSettle == nil {
                // They stayed out: nothing to settle, the editor rests after this update.
                input.reveal = nil
                let reveal = actions.reveal
                Task { @MainActor in reveal(nil) }
            }
        }
        // Settling toward a state the editor no longer has (a track chosen, a panel opened meanwhile): it rests at once, and
        // the editor after this update.
        if let settle = revealSettle, input.panelIsOpen || input.tracks?.isExpanded != (settle.spring.to == 1) {
            stopRevealLink()
            input.reveal = nil
            let reveal = actions.reveal
            Task { @MainActor in reveal(nil) }
        }
        guard input != self.input || content.geometry == nil else {
            content.show(geometry ?? TimelineGeometry(input), sources: sources)
            return
        }
        let choiceChanged = self.input.map { $0.tracks != input.tracks } ?? false
        self.input = input
        // A pinch in progress keeps its own zoom until it ends.
        var shown = input
        if pinchStart != nil { shown.pointsPerSecond = TimelineGeometry.basePointsPerSecond * zoom }
        zoom = shown.pointsPerSecond / TimelineGeometry.basePointsPerSecond
        let next = TimelineGeometry(shown)
        let change = TimelineChange(from: geometry, to: next)
        // The tracks coming out or going away cross-fade while the editor gives the timeline its new height; their icons glide
        // to their places on their own (`TimelineLaneGutterView`).
        if choiceChanged, window != nil, geometry.map({ $0.lanes.map(\.lane) != next.lanes.map(\.lane) }) == true {
            let options: UIView.AnimationOptions = [.transitionCrossDissolve, .allowUserInteraction]
            UIView.transition(with: backdrop, duration: 0.2, options: options) {}
            UIView.transition(with: scrollView, duration: 0.2, options: options) {
                self.apply(next, sources: sources, change: change)
            }
        } else {
            apply(next, sources: sources, change: change)
        }
        showWantedLane()
    }

    /// The player's clock: followed unless a finger is moving the content or holding a handle.
    func show(time: TimeInterval) {
        // No finger moving the content and no glide: a scrub whose end never came is over. (`isTracking` can't tell: it turns
        // off while a finger that rested first still drags.)
        if isScrubbing, !isContentMoving { endScrub() }
        guard !isScrubbing, handle == nil, pinchStart == nil else { return }
        guard abs(time - self.time) > 0.000_1 || scrollView.contentOffset.x != offset(for: time) else { return }
        self.time = time
        setOffset(for: time)
    }

    /// A finger is dragging the content, or it still glides.
    private var isContentMoving: Bool {
        let pan = scrollView.panGestureRecognizer.state
        return pan == .began || pan == .changed || scrollView.isDragging || scrollView.isDecelerating
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        let half = bounds.width / 2
        if scrollView.contentInset.left != half {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: half, bottom: 0, right: half)
        }
        sizeContent()
        let top: CGFloat = geometry?.isCompact == true ? 16 : 14
        playhead.frame = CGRect(x: half - 1, y: top, width: 2, height: max(0, bounds.height - top))
        let fadeHeight: CGFloat = 22
        fade.frame = CGRect(x: 0, y: bounds.height - fadeHeight, width: bounds.width, height: fadeHeight)
        fadeGradient.frame = fade.bounds
        layoutBubble()
        setOffset(for: displayedTime)
        showWantedLane()
    }

    private func apply(_ geometry: TimelineGeometry, sources: TimelineContentView.Sources, change: TimelineChange = .none) {
        self.geometry = geometry
        backdrop.show(geometry, change: change)
        gutter.show(geometry, change: change)
        sizeContent()
        content.show(geometry, sources: sources, change: change)
        setOffset(for: displayedTime)
        setNeedsLayout()
    }

    /// The content as wide as the video and as tall as its tracks (at least the timeline).
    private func sizeContent() {
        let size = CGSize(width: geometry?.contentWidth ?? 0, height: max(bounds.height, geometry?.contentHeight ?? 0))
        content.frame = CGRect(origin: .zero, size: size)
        if scrollView.contentSize != size { scrollView.contentSize = size }
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
        scrollView.contentOffset = CGPoint(x: offset(for: time), y: min(max(0, scrollView.contentOffset.y), maximumTrackOffset))
        isApplyingOffset = false
        // Not the finger's doing: a drag adds up only what the finger moves from here.
        lastOffsetX = scrollView.contentOffset.x
        followTracks()
    }

    // MARK: - Tracks up and down

    /// How far the tracks can scroll up.
    private var maximumTrackOffset: CGFloat {
        max(0, scrollView.contentSize.height - bounds.height)
    }

    /// The strips and the gutter follow the tracks up and down, under the ruler; the fade shows while part of a track is
    /// hidden below (not just the room under the last one).
    private func followTracks() {
        let y = scrollView.contentOffset.y
        let top = geometry?.tracksTop ?? 0
        let below = CGRect(x: 0, y: top, width: bounds.width, height: max(0, bounds.height - top))
        for view in [backdrop, gutter] as [UIView] {
            if view.frame != below { view.frame = below }
            if view.bounds.origin.y != top + y { view.bounds.origin.y = top + y }
        }
        let lastTrackEnd = geometry?.lanes.last.map { $0.y + $0.height } ?? 0
        // Under a finger the editor gives the timeline its height a moment after the tracks move: nothing is hidden for long.
        fade.isHidden = isRevealing || lastTrackEnd <= y + bounds.height + 0.5
        content.scrolled(to: CGRect(origin: scrollView.contentOffset, size: bounds.size))
    }

    /// The track to keep in sight: the picked item's, else the first whose tools are open.
    private var wantedLane: TimelineGeometry.LaneFrame? {
        guard let geometry else { return nil }
        let input = geometry.input
        if input.selection?.joinID == nil, let lane = input.selection?.lane, let frame = geometry.lane(lane) { return frame }
        return geometry.lanes.first { $0.lane == input.focusedLane || input.activeLanes.contains($0.lane) }
    }

    /// Scrolls the tracks to the one to keep in sight when it changes and is out of sight (above, under the ruler, or below).
    private func showWantedLane() {
        guard !isRevealing else { return }
        let frame = wantedLane
        guard frame?.lane != shownLane else { return }
        shownLane = frame?.lane
        guard let frame, !isScrubbing, maximumTrackOffset > 0 else { return }
        let top = geometry?.tracksTop ?? 0
        let current = trackScroll?.to ?? scrollView.contentOffset.y
        var target = current
        if frame.y < current + top {
            target = frame.y - top
        } else if frame.y + frame.height > current + bounds.height {
            target = frame.y + frame.height + 8 - bounds.height
        }
        scrollTracks(to: min(max(0, target), maximumTrackOffset))
    }

    /// Eases the tracks to `y` (at once with Reduce Motion), the playhead's time untouched.
    private func scrollTracks(to y: CGFloat) {
        guard abs(y - scrollView.contentOffset.y) > 0.5 else { return }
        guard !UIAccessibility.isReduceMotionEnabled else {
            setTrackOffset(y)
            return
        }
        trackScroll = (scrollView.contentOffset.y, y, CACurrentMediaTime())
        if trackLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(stepTrackScroll(_:)))
            link.add(to: .main, forMode: .common)
            trackLink = link
        }
    }

    @objc private func stepTrackScroll(_ link: CADisplayLink) {
        guard let scroll = trackScroll else {
            stopTrackScroll()
            return
        }
        let progress = min(1, (link.targetTimestamp - scroll.start) / 0.3)
        let eased = 1 - pow(1 - progress, 3)
        setTrackOffset(scroll.from + (scroll.to - scroll.from) * eased)
        if progress >= 1 { stopTrackScroll() }
    }

    private func stopTrackScroll() {
        trackLink?.invalidate()
        trackLink = nil
        trackScroll = nil
    }

    private func setTrackOffset(_ y: CGFloat) {
        isApplyingOffset = true
        scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: min(max(0, y), maximumTrackOffset))
        isApplyingOffset = false
        followTracks()
    }

    // MARK: - Every track out, or the current one alone

    /// The tracks are on their way out or away, under a finger or settling.
    private var isRevealing: Bool { input?.reveal != nil }

    /// Where the tracks are now: under a finger or settling, else 0 or 1.
    private var currentReveal: CGFloat {
        input?.reveal ?? (input?.tracks?.isExpanded == true ? 1 : 0)
    }

    /// A drag up or down (clearly more than across) with nothing open, not on a handle or the picked item, and not while the
    /// tracks scroll that way themselves (more of them than room, with every one out: up while there are more below, down
    /// until the first is back in sight).
    private func canReveal(_ pan: UIPanGestureRecognizer) -> Bool {
        guard let geometry, geometry.input.tracks != nil, !geometry.isCompact, revealSpan > 1, handle == nil, pinchStart == nil
        else { return false }
        if let point = touchDown, geometry.dragTarget(at: point) != nil { return false }
        // In the window: the timeline itself moves with the finger.
        let moved = pan.translation(in: nil)
        let way = moved == .zero ? pan.velocity(in: nil) : moved
        guard abs(way.y) > abs(way.x) * 1.2 else { return false }
        if geometry.input.tracks?.isExpanded == true, maximumTrackOffset > 0.5 {
            return way.y > 0 && scrollView.contentOffset.y <= 0.5
        }
        return true
    }

    @objc private func revealPanned(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            // A settle the finger catches goes on from where it is.
            revealStart = currentReveal
            stopRevealLink()
            endScrub()
            gutter.press(false)
        case .changed:
            guard let start = revealStart, revealSpan > 0 else { return }
            setReveal(Self.stretched(start - pan.translation(in: nil).y / revealSpan, span: revealSpan))
        default:
            guard revealStart != nil else { return }
            revealStart = nil
            // Up is toward every track out.
            let speed = -pan.velocity(in: nil).y
            let now = currentReveal
            let expanded = pan.state == .ended && abs(speed) > Self.throwSpeed ? speed > 0 : now > 0.5
            settleTracks(expanded: expanded, from: now, velocity: speed / max(1, revealSpan))
        }
    }

    /// Points a second past which a finger letting go throws the tracks its way, however far it dragged them.
    private static let throwSpeed: CGFloat = 350

    /// Past either end the timeline stretches less and less, up to 18 pt (like a list at its edge).
    private static func stretched(_ reveal: CGFloat, span: CGFloat) -> CGFloat {
        func band(_ beyond: CGFloat) -> CGFloat { 18 * (1 - exp(-beyond * span / 60)) / span }
        if reveal > 1 { return 1 + band(reveal - 1) }
        if reveal < 0 { return -band(-reveal) }
        return reveal
    }

    /// Every track out or the current one alone: the editor is told at once (a tick when that changes it), and the timeline
    /// springs there from `from`, carried on by `velocity` (reveal per second).
    private func settleTracks(expanded: Bool, from: CGFloat, velocity: CGFloat) {
        if expanded != (input?.tracks?.isExpanded == true) { Haptics.light() }
        setReveal(from)
        actions.expandTracks(expanded)
        spring(toExpanded: expanded, from: from, velocity: velocity)
    }

    /// The tracks spring from `from` to every one out, or the current one alone, where the editor has them already.
    private func spring(toExpanded expanded: Bool, from: CGFloat, velocity: CGFloat) {
        let spring = TimelineRevealSpring(
            from: from, to: expanded ? 1 : 0, velocity: velocity, passesTheMark: !UIAccessibility.isReduceMotionEnabled
        )
        revealSettle = (spring, CACurrentMediaTime())
        if revealLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(stepReveal(_:)))
            link.add(to: .main, forMode: .common)
            revealLink = link
        }
    }

    @objc private func stepReveal(_ link: CADisplayLink) {
        guard let settle = revealSettle else {
            stopRevealLink()
            return
        }
        let time = link.targetTimestamp - settle.start
        if settle.spring.isSettled(at: time) {
            // At rest where the editor has them.
            stopRevealLink()
            setReveal(nil)
        } else {
            setReveal(settle.spring.value(at: time))
        }
    }

    private func stopRevealLink() {
        revealLink?.invalidate()
        revealLink = nil
        revealSettle = nil
    }

    /// The tracks `reveal` of the way out (nil: at rest), drawn at once and told to the editor, which gives the timeline its
    /// height.
    private func setReveal(_ reveal: CGFloat?) {
        guard var input, input.reveal != reveal else { return }
        input.reveal = reveal
        self.input = input
        apply(TimelineGeometry(input), sources: currentSources)
        actions.reveal(reveal)
    }

    private func layoutBubble() {
        let size = bubble.intrinsicContentSize
        bubble.frame = CGRect(x: bounds.width / 2 + 1 - size.width / 2, y: 0, width: size.width, height: 20)
    }

    // MARK: - Scrolling

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        stopTrackScroll()
        isScrubbing = true
        hasScrubbed = false
        dragStartX = scrollView.contentOffset.x
        fingerX = dragStartX
        lastOffsetX = dragStartX
        lastSnap = nil
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        followTracks()
        guard !isApplyingOffset, isScrubbing, let geometry else { return }
        // Up and down only: the tracks move, the playhead's time stays.
        guard hasScrubbed || abs(scrollView.contentOffset.x - dragStartX) > 0.5 else { return }
        hasScrubbed = true
        let duration = geometry.input.duration
        func seconds(at x: CGFloat) -> TimeInterval { min(max(0, TimeInterval((x + bounds.width / 2) / pointsPerSecond)), duration) }
        var time = seconds(at: scrollView.contentOffset.x)
        if scrollView.isTracking {
            // Snapping goes by where the finger has taken the content (the scroll view's own steps added up), not by the offset
            // a snap left: the playhead holds on a cut only while the finger is within reach of it, so a slow drag leaves it as a
            // fast one does. Snapping the offset back at every step held it there for good, each slow step being shorter than
            // the reach.
            fingerX += scrollView.contentOffset.x - lastOffsetX
            let finger = seconds(at: fingerX)
            if let snap = TimelineSnapping.snapped(finger, to: geometry.snapTimes, pointsPerSecond: pointsPerSecond) {
                if lastSnap.map({ abs($0 - snap) > 0.000_1 }) ?? true {
                    Haptics.snap()
                    content.flashSnap(at: snap)
                }
                lastSnap = snap
                time = snap
                setOffset(for: snap)
            } else {
                if lastSnap != nil { setOffset(for: finger) }
                lastSnap = nil
                time = finger
            }
            lastOffsetX = scrollView.contentOffset.x
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
        if hasScrubbed { actions.endScrub() }
        hasScrubbed = false
    }

    // MARK: - Gestures

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer, gestureRecognizer.view === scrollView {
            // A finger stopping a glide: UIKit may not say the glide ended, so it ends here (a drag from it scrubs anew).
            if scrollView.isDecelerating { endScrub() }
            touchDown = touch.location(in: content)
            touchDownOnScreen = touch.location(in: self)
        }
        return true
    }

    /// The point is on the ruler while tracks are scrolled under it: what is under the ruler can't be reached there.
    private func isOverRuler(_ onScreen: CGPoint) -> Bool {
        scrollView.contentOffset.y > 0.5 && onScreen.y < (geometry?.tracksTop ?? 0)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === press || other === press
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === revealPan, let pan = gestureRecognizer as? UIPanGestureRecognizer {
            return canReveal(pan)
        }
        if gestureRecognizer === press {
            let onScreen = gestureRecognizer.location(in: self)
            guard let geometry, !isOverRuler(onScreen) else { return false }
            return geometry.chooserHit(atViewportX: onScreen.x, y: gestureRecognizer.location(in: content).y)
        }
        if gestureRecognizer is UILongPressGestureRecognizer, gestureRecognizer.view === scrollView {
            // A hold begins only on a clip (Reorder): anywhere else a finger that rests before moving still scrubs.
            guard let geometry, !isOverRuler(gestureRecognizer.location(in: self)) else { return false }
            let point = gestureRecognizer.location(in: content)
            guard geometry.handle(at: point) == nil, case .clip? = geometry.hit(at: point) else { return false }
            return true
        }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return super.gestureRecognizerShouldBegin(gestureRecognizer) }
        if pan.view === scrollView, pan !== scrollView.panGestureRecognizer {
            // A handle's pan only starts on a handle, or on the picked item's body (to move it).
            guard let point = touchDown, let geometry, touchDownOnScreen.map(isOverRuler(_:)) != true else { return false }
            return geometry.dragTarget(at: point) != nil
        }
        if pan.allowedTouchTypes.isEmpty {
            return pan.modifierFlags.contains(.control) || pan.modifierFlags.contains(.command)
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        // Not while a finger drags the tracks; a tap while they settle puts them in place first (as a tap stops a glide).
        guard revealStart == nil else { return }
        if revealSettle != nil {
            stopRevealLink()
            setReveal(nil)
        }
        guard let geometry else { return }
        let point = recognizer.location(in: content)
        let onScreen = recognizer.location(in: self)
        guard !isOverRuler(onScreen) else {
            actions.tap(nil)
            return
        }
        // ▾ beside the current track's icon, before the track and what scrolls under it: the tracks come out (or go away) as
        // under a finger. With Reduce Motion they change in place.
        if geometry.chooserHit(atViewportX: onScreen.x, y: point.y) {
            if UIAccessibility.isReduceMotionEnabled || revealSpan <= 1 || geometry.isCompact {
                actions.tap(.trackChooser)
            } else {
                let isExpanded = geometry.input.tracks?.isExpanded == true
                settleTracks(expanded: !isExpanded, from: currentReveal, velocity: 0)
            }
            return
        }
        let lane = geometry.laneHit(atViewportX: onScreen.x, y: point.y, viewportWidth: bounds.width)
        let target: TimelineGeometry.Hit?
        if onScreen.x <= TimelineGeometry.gutterWidth, let lane {
            // Items scroll under the gutter: a tap there is for the track.
            target = lane
        } else {
            // A tap on a handle does nothing (the handle is for dragging).
            guard geometry.handle(at: point) == nil else { return }
            target = geometry.hit(at: point) ?? lane
        }
        // Every track out: if the tap puts them away (a track chosen, an item picked), they go on ▾'s spring from where they
        // are, the editor holding them out until the next update says (`update(input:sources:)`).
        if target != nil, geometry.input.tracks?.isExpanded == true, !geometry.isCompact, revealSpan > 1,
           !UIAccessibility.isReduceMotionEnabled {
            setReveal(1)
            awaitsTapResult = true
        }
        actions.tap(target)
    }

    @objc private func pressed(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began: gutter.press(true)
        case .changed: break
        default: gutter.press(false)
        }
    }

    @objc private func handlePanned(_ recognizer: UIPanGestureRecognizer) {
        guard let geometry else { return }
        switch recognizer.state {
        case .began:
            guard let point = touchDown, let found = geometry.dragTarget(at: point) else { return }
            // Stopping a glide this way tells no one it ended.
            endScrub()
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)
            handle = (found.target, time, 0)
            lastHandleSnap = nil
            actions.beginHandle(found.target, geometry.snapTimes)
            Haptics.selection()
        case .changed:
            guard var held = handle else { return }
            let offset = TimeInterval(recognizer.translation(in: self).x / pointsPerSecond)
            let result = actions.moveHandle(offset)
            if let snap = result.snap, lastHandleSnap.map({ abs($0 - snap) > 0.000_1 }) ?? true { content.flashSnap(at: snap) }
            lastHandleSnap = result.snap
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

    @objc private func held(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let geometry, handle == nil else { return }
        let point = recognizer.location(in: content)
        guard geometry.handle(at: point) == nil, case .clip(let id)? = geometry.hit(at: point) else { return }
        Haptics.selection()
        actions.holdClip(id)
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
        sizeContent()
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

    /// A swipe up or down moves the playhead a second (a frame's precision is ‹ › under the preview); Next cut and Previous
    /// cut jump between clips.
    override func accessibilityIncrement() {
        actions.nudge(1)
    }

    override func accessibilityDecrement() {
        actions.nudge(-1)
    }
}
