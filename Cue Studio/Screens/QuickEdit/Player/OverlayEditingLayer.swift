//
//  OverlayEditingLayer.swift
//  Cue Studio
//

import SwiftUI

/// Editing right on the preview. Every text on screen can be tapped: the picked one gets a yellow
/// outline 5 pt around it, turned with it, a ✕ to delete it, a corner handle that resizes and turns it and a tab on each side
/// that makes its lines longer or shorter (`TextHandle`); tapped again, Text style opens. One finger on a text moves it; two
/// (anywhere on the preview once a text is picked) move, resize and turn it at once, and lifting or adding a finger midway
/// carries on without a jump (`TextTransformRecognizer`). It sticks to the middle lines and to straight, with a tick; the
/// platform's safe area shows dashed, and its turn in degrees while it turns. With keyframes, the gesture sets the one at the
/// playhead. Dragging the caption moves every caption up or down (sticking to top, middle and
/// bottom). Each photo or video in a window showing at the playhead has its handle, stacked as the video draws them (the
/// picked one on top, so it can be moved even where another covers it); a tap goes to the one under the finger, and tapping
/// again where several overlap goes to the next one down (`QuickEditViewModel.tapMedia`). It moves (with the same guides) and
/// pinches. A split screen's areas are under all of it (`SplitAreaLayer`).
///
/// Texts, photos and videos are drawn into the video exactly as they export; while a finger moves one, the video leaves it
/// out (`beginOverlayDrag`) and a copy follows the finger, so it never shows twice; the change lands when it lifts.
struct OverlayEditingLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    private enum Drag: Equatable {
        case caption(UUID, y: Double)
        case media(UUID, offset: CGSize)
    }

    @State private var drag: Drag?
    /// The text a gesture has (`TextManipulation`).
    @State private var manipulation: TextManipulation?
    /// Paints a text with an effect anew away from the main thread while a gesture changes it.
    @State private var drawer = TextPictureDrawer()
    /// Where the dragged caption is now, so it ticks once as it sticks to a place, not at every move inside it.
    private var draggedCaptionY: Double? {
        if case .caption(_, let y) = drag { y } else { nil }
    }
    @State private var guides: (vertical: Bool, horizontal: Bool) = (false, false)
    /// The photo or video being pinched, and by how much.
    @State private var pinch: (id: UUID, scale: CGFloat)?
    /// The picture of the photo or video under the finger, while one moves.
    @State private var proxy: (id: UUID, image: UIImage)?

    @Environment(VideoThumbnailService.self) private var thumbnails
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack(alignment: .topLeading) {
            // With a text picked, two fingers anywhere on the preview resize and turn it.
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(takesTextGestures && viewModel.selection?.textID != nil)
                .accessibilityHidden(true)
            // Under everything else: the split screen's areas (texts, captions and windows over them stay reachable).
            SplitAreaLayer(viewModel: viewModel, size: size)
            if drag != nil || manipulation != nil { dragGuides }
            if !viewModel.player.isPlaying, let caption = viewModel.captions.previewCaption(in: size) {
                captionHandle(caption.id, frame: caption.frame)
            }
            ForEach(handledMedia) { media in
                mediaHandle(media)
            }
            ForEach(viewModel.overlays.visibleTexts) { text in
                TextHandle(
                    viewModel: viewModel, text: text, size: size, manipulation: manipulation?.id == text.id ? manipulation : nil,
                    onGrip: { grip, value in handle(grip, of: text, value) }, space: Self.space
                )
            }
            if let manipulation, manipulation.turn != 0 { turnBadge(manipulation) }
            // Over everything while their panels are open: the mask's handles and the Blur areas.
            MaskEditingLayer(viewModel: viewModel, size: size)
            BlurEditingLayer(viewModel: viewModel, size: size)
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: Self.space)
        .gesture(TextTransformGesture(space: Self.space, shouldStart: { location, fingers in
            textTarget(at: location, fingers: fingers) != nil
        }, onChange: follow))
    }

    private static let space = "edit.preview.space"

    /// The windows showing at the playhead, bottom to top, with the picked one last (on top, so it stays reachable).
    private var handledMedia: [MediaOverlay] {
        // While Mask is open, a drag on the picked media moves its mask (`MaskEditingLayer`), not the media.
        let windows = viewModel.overlays.visibleMediaStack.filter {
            $0.layout == .window && !(viewModel.panel == .mask && $0.id == viewModel.selection?.mediaID)
        }
        let picked = viewModel.selection?.mediaID
        return windows.filter { $0.id != picked } + windows.filter { $0.id == picked }
    }

    // MARK: - Guides

    @ViewBuilder
    private var dragGuides: some View {
        let safe = viewModel.overlays.safeArea(in: size)
        RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous)
            .strokeBorder(Palette.Camera.safeZoneLine, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(width: safe.width, height: safe.height)
            .offset(x: safe.minX, y: safe.minY)
            .allowsHitTesting(false)
        let guides = manipulation?.guides ?? guides
        if guides.vertical {
            Rectangle().fill(Palette.acc).frame(width: 1, height: size.height)
                .offset(x: size.width / 2 - 0.5)
                .allowsHitTesting(false)
        }
        if guides.horizontal {
            Rectangle().fill(Palette.acc).frame(width: size.width, height: 1)
                .offset(y: size.height / 2 - 0.5)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Text

    /// Texts take gestures unless Mask's or Blur area's handles are over them.
    private var takesTextGestures: Bool {
        viewModel.panel != .mask && viewModel.panel != .blur
    }

    /// The text a gesture whose fingers are at `point` (their middle) is for: the picked one under them, else the top one under
    /// them, else, with two fingers, the picked one wherever they are (but on a photo or video). Never one whose handle the
    /// finger is on.
    private func textTarget(at point: CGPoint, fingers: Int) -> TextOverlay? {
        guard takesTextGestures, viewModel.isReady else { return nil }
        let texts = viewModel.overlays.visibleTexts
        let picked = texts.first { viewModel.selection == .text($0.id) }
        if let picked, isOnHandle(point, of: picked) { return nil }
        if let picked, contains(point, picked) { return picked }
        if let top = texts.reversed().first(where: { contains(point, $0) }) { return top }
        // Two fingers on a photo or video are its own pinch.
        guard fingers > 1, viewModel.overlays.mediaHits(at: point, in: size).isEmpty else { return nil }
        return picked
    }

    /// `point` falls on the text's box (turned as it is, 44 points at least each way).
    private func contains(_ point: CGPoint, _ text: TextOverlay) -> Bool {
        let frame = viewModel.overlays.frame(ofText: text, in: size)
        let local = unturned(point, around: CGPoint(x: frame.midX, y: frame.midY), by: viewModel.overlays.rotation(ofText: text))
        return abs(local.x) <= max(frame.width, Metrics.hitTarget) / 2 && abs(local.y) <= max(frame.height, Metrics.hitTarget) / 2
    }

    /// `point` falls on one of the picked text's handles: ✕, the corner, a side tab.
    private func isOnHandle(_ point: CGPoint, of text: TextOverlay) -> Bool {
        let frame = viewModel.overlays.frame(ofText: text, in: size)
        let local = unturned(point, around: CGPoint(x: frame.midX, y: frame.midY), by: viewModel.overlays.rotation(ofText: text))
        let half = CGSize(width: frame.width / 2 + 5, height: frame.height / 2 + 5)
        let spots = [
            CGPoint(x: -half.width, y: -half.height), CGPoint(x: half.width, y: half.height), CGPoint(x: -half.width, y: 0), CGPoint(x: half.width, y: 0),
        ]
        return spots.contains { hypot(local.x - $0.x, local.y - $0.y) < Metrics.hitTarget / 2 }
    }

    /// `point` relative to `center`, turned back by `rotation`: where it is on an upright box.
    private func unturned(_ point: CGPoint, around center: CGPoint, by rotation: Double) -> CGPoint {
        let dx = point.x - center.x, dy = point.y - center.y
        let cosine = CGFloat(cos(-rotation)), sine = CGFloat(sin(-rotation))
        return CGPoint(x: dx * cosine - dy * sine, y: dx * sine + dy * cosine)
    }

    /// The preview's one- and two-finger gesture on a text, the fingers' middle at `location`.
    private func follow(_ recognizer: TextTransformRecognizer, at location: CGPoint) {
        switch recognizer.state {
        case .began:
            guard let text = textTarget(at: location, fingers: recognizer.fingers) else { return }
            begin(.body, on: text)
            update(translation: recognizer.translation, scale: recognizer.scale, rotation: recognizer.rotation)
        case .changed:
            update(translation: recognizer.translation, scale: recognizer.scale, rotation: recognizer.rotation)
        case .ended:
            commit()
        default:
            cancel()
        }
    }

    /// A handle moved (nil: let go).
    private func handle(_ grip: TextGrip, of text: TextOverlay, _ value: DragGesture.Value?) {
        guard let value else {
            commit()
            return
        }
        if manipulation == nil { begin(grip, on: text) }
        guard let manipulation, manipulation.grip == grip else { return }
        let center = manipulation.center
        switch grip {
        case .corner:
            // Round the text's middle: as far from it as the finger goes, turned as the finger turns.
            let start = CGPoint(x: value.startLocation.x - center.x, y: value.startLocation.y - center.y)
            let now = CGPoint(x: value.location.x - center.x, y: value.location.y - center.y)
            let scale = hypot(now.x, now.y) / max(1, hypot(start.x, start.y))
            let rotation = remainder(atan2(now.y, now.x) - atan2(start.y, start.x), 2 * .pi)
            update(translation: .zero, scale: scale, rotation: rotation)
        case .leading, .trailing:
            widen(along: value.translation)
        case .body:
            break
        }
    }

    /// A gesture took the text: the player stops, the text is picked and the video leaves it out; its picture follows.
    private func begin(_ grip: TextGrip, on text: TextOverlay) {
        let overlays = viewModel.overlays
        viewModel.player.pause()
        if viewModel.selection != .text(text.id) { viewModel.selection = .text(text.id) }
        let frame = overlays.frame(ofText: text, in: size)
        let state = overlays.motionState(of: .text(text.id))
        let shownScale = text.keyframes.isEmpty ? 1 : state.scale
        var started = TextManipulation(
            id: text.id, grip: grip, center: CGPoint(x: frame.midX, y: frame.midY), box: frame.size,
            rotation: text.graphic.map(\.rotation) ?? overlays.rotation(ofText: text), shownScale: shownScale, opacity: state.opacity,
            lineWidth: TextOverlayRenderer.laidOutLineWidth(of: text) ?? TextOverlayRenderer.currentLineWidth(of: text)
        )
        started.pixels = pickUpPixels(for: text, shownScale: shownScale)
        started.drawing = overlays.drawing(ofText: text, width: size.width, pixels: started.pixels)
        manipulation = started
        overlays.beginOverlayDrag(.text(text.id))
    }

    /// The gesture so far: moved `translation` points, `scale` times as big, turned `rotation` radians.
    private func update(translation: CGSize, scale: CGFloat, rotation: CGFloat) {
        guard var next = manipulation, let text = viewModel.edit.texts.first(where: { $0.id == next.id }) else { return }
        let proposed = OverlayPoint(
            x: Double((next.center.x + translation.width) / max(1, size.width)),
            y: Double((next.center.y + translation.height) / max(1, size.height))
        )
        let snapped = OverlaysViewModel.snapped(proposed)
        if (snapped.vertical && !next.guides.vertical) || (snapped.horizontal && !next.guides.horizontal) { Haptics.snap() }
        next.guides = (snapped.vertical, snapped.horizontal)
        next.offset = CGSize(width: CGFloat(snapped.center.x) * size.width - next.center.x, height: CGFloat(snapped.center.y) * size.height - next.center.y)
        next.factor = viewModel.overlays.allowedScale(Double(scale), forText: text)
        let turned = OverlaysViewModel.snappedRotation(next.rotation + Double(rotation))
        if turned.snapped && !next.turnSnapped { Haptics.snap() }
        next.turnSnapped = turned.snapped
        next.turn = turned.rotation - next.rotation
        if next.needsSharperPicture(displayScale: displayScale) {
            // Grown well past what it was drawn at: drawn again at its new size, so it stays sharp under the fingers.
            let pixels = min(displayScale * CGFloat(next.shownScale * next.factor), 4096 / max(1, size.width))
            if text.effect == nil {
                next.pixels = pixels
                next.drawing = viewModel.overlays.drawing(ofText: text, width: size.width, pixels: pixels) ?? next.drawing
            } else {
                next.asked = pixels
                redraw(text, pixels: pixels, for: next.gesture)
            }
        }
        manipulation = next
    }

    /// A side tab moved by `translation`: the lines as long as the finger makes them (never shorter than the longest word),
    /// laid out again when they break differently; the other side stays where it was.
    private func widen(along translation: CGSize) {
        guard var next = manipulation, let text = viewModel.edit.texts.first(where: { $0.id == next.id }) else { return }
        let axis = CGPoint(x: cos(next.rotation), y: sin(next.rotation))
        let along = Double(translation.width * axis.x + translation.height * axis.y)
        let pointsPerDesign = Double(size.width / TextOverlayRenderer.referenceWidth) * next.shownScale
        let change = (next.grip == .trailing ? along : -along) / max(0.001, pointsPerDesign)
        let longest = TextOverlayRenderer.longestWordWidth(of: text)
        let width = min(max(next.lineWidth + change, longest, TextBlock.minimumWidth), Double(TextOverlayRenderer.referenceWidth) * 3)
        guard abs(width - (next.newLineWidth ?? next.lineWidth)) >= 0.5 else { return }
        next.newLineWidth = width
        let widened = OverlaysViewModel.text(text, withLineWidth: width)
        if text.effect != nil {
            // Its lines break anew as they are painted; the side holds still as the picture lands.
            redraw(widened, pixels: next.pixels, for: next.gesture)
        } else if let drawing = viewModel.overlays.drawing(ofText: widened, width: size.width, pixels: next.pixels) {
            next.drawing = drawing
        }
        next.offset = next.sideHeldOffset
        manipulation = next
    }

    /// The fingers lifted: the change lands, one undo step, and the video draws the text again where it now is.
    private func commit() {
        guard let done = manipulation else { return }
        let center = OverlayPoint(x: Double(done.currentCenter.x / max(1, size.width)), y: Double(done.currentCenter.y / max(1, size.height)))
        if done.grip.isSide {
            if let width = done.newLineWidth { viewModel.overlays.setTextBlock(done.id, width: width, center: center) }
        } else if done.offset != .zero || done.factor != 1 || done.turn != 0 {
            viewModel.overlays.transformText(done.id, center: center, factor: done.factor, rotation: done.currentRotation)
        }
        manipulation = nil
        drawer.cancel()
        viewModel.overlays.endOverlayDrag()
    }

    /// The gesture was called off: the text stays as it was.
    private func cancel() {
        guard manipulation != nil else { return }
        manipulation = nil
        drawer.cancel()
        viewModel.overlays.endOverlayDrag()
    }

    /// How sharp the picture under the fingers is drawn: a text with an effect as the video draws it, so its painting is found
    /// in the cache instead of painted again while the fingers wait; any other at the screen's own sharpness.
    private func pickUpPixels(for text: TextOverlay, shownScale: Double) -> CGFloat {
        let screen = displayScale * CGFloat(max(1, shownScale))
        guard text.effect != nil, let upright = viewModel.look.recordingUprightSize, size.width > 0 else { return screen }
        let frameWidth = EditFraming.cropRect(uprightSize: upright, edit: viewModel.edit).width * TextOverlayRenderer.drawnScale(for: text)
        return frameWidth > 0 ? frameWidth / size.width : screen
    }

    /// `text`'s picture at `pixels` per point, painted away from the main thread; it lands on the gesture if it is still the
    /// same one (a side tab's middle following the new width).
    private func redraw(_ text: TextOverlay, pixels: CGFloat, for gesture: UUID) {
        let work = viewModel.overlays.drawingWork(ofText: text, width: size.width, pixels: pixels)
        drawer.draw(work) { picture in
            guard var current = manipulation, current.gesture == gesture, let picture else { return }
            current.drawing = picture
            current.pixels = pixels
            if pixels >= current.asked ?? 0 { current.asked = nil }
            if current.grip.isSide { current.offset = current.sideHeldOffset }
            manipulation = current
        }
    }

    /// The turn in degrees over the text while it turns.
    private func turnBadge(_ manipulation: TextManipulation) -> some View {
        let degrees = Int((OverlaysViewModel.normalizedRotation(manipulation.currentRotation) * 180 / .pi).rounded())
        let reach = max(manipulation.currentBox.width, manipulation.currentBox.height) / 2 + 28
        let center = manipulation.currentCenter
        return Text(verbatim: "\(degrees)°")
            .font(.footnote.weight(.semibold).monospacedDigit())
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .toastSurface(in: Capsule())
            .position(x: min(max(center.x, 40), size.width - 40), y: min(max(center.y - reach, 20), size.height - 20))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// VoiceOver's drag and pinch: a step up, down, left or right, bigger or smaller (`OverlaysViewModel+Accessibility`).
    @ViewBuilder
    private func placingActions(_ item: OverlaysViewModel.MotionItem) -> some View {
        let step = OverlaysViewModel.overlayStep
        Button("Move up") { viewModel.overlays.nudgeOverlay(item, x: 0, y: -step) }
        Button("Move down") { viewModel.overlays.nudgeOverlay(item, x: 0, y: step) }
        Button("Move left") { viewModel.overlays.nudgeOverlay(item, x: -step, y: 0) }
        Button("Move right") { viewModel.overlays.nudgeOverlay(item, x: step, y: 0) }
        Button("Bigger") { viewModel.overlays.resizeOverlay(item, bigger: true) }
        Button("Smaller") { viewModel.overlays.resizeOverlay(item, bigger: false) }
    }

    private func endDrag() {
        drag = nil
        guides = (false, false)
    }

    // MARK: - Caption

    private func captionHandle(_ id: UUID, frame: CGRect) -> some View {
        let isSelected = viewModel.selection == .caption(id)
        let draggedY: Double? = if case .caption(id, let y) = drag { y } else { nil }
        let offset = draggedY.map { CGFloat($0 - viewModel.captions.captionY) * size.height } ?? 0
        return ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: max(frame.width, Metrics.hitTarget), height: max(frame.height, Metrics.hitTarget))
                .onTapGesture { viewModel.captions.tapCaption(id) }
                .gesture(captionGesture(id))
            if isSelected || draggedY != nil {
                RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous)
                    .strokeBorder(Palette.acc, lineWidth: 2)
                    .frame(width: frame.width + 8, height: frame.height + 8)
                    .allowsHitTesting(false)
            }
        }
        .position(x: frame.midX, y: frame.midY + offset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Caption"))
        .accessibilityHint(Text("Drag up or down to move every caption"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("edit.captionHandle")
    }

    private func captionGesture(_ id: UUID) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if drag == nil {
                    viewModel.player.pause()
                    if viewModel.selection != .caption(id) { viewModel.selection = .caption(id) }
                }
                let placed = CaptionsViewModel.snappedCaption(
                    viewModel.captions.captionY + Double(value.translation.height / max(1, size.height)),
                    seam: viewModel.captions.splitSeamAtPlayhead
                )
                if placed.stop != nil, placed.y != draggedCaptionY { Haptics.snap() }
                guides = (false, placed.stop == 0.5)
                drag = .caption(id, y: placed.y)
            }
            .onEnded { value in
                viewModel.captions.moveCaptions(toY: viewModel.captions.captionY + Double(value.translation.height / max(1, size.height)))
                endDrag()
            }
    }

    // MARK: - Media

    private func mediaHandle(_ media: MediaOverlay) -> some View {
        let rect = viewModel.overlays.frame(ofMedia: media, in: size)
        let isSelected = viewModel.selection == .media(media.id)
        let offset: CGSize = if case .media(media.id, let moved) = drag { moved } else { .zero }
        let scale: CGFloat = pinch?.id == media.id ? pinch?.scale ?? 1 : 1
        let isMoving = offset != .zero || scale != 1
        return ZStack {
            if isMoving, let proxy, proxy.id == media.id {
                // The video leaves it out while it moves: this is the only copy.
                Image(uiImage: proxy.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: rect.width * scale, height: rect.height * scale)
                    .clipped()
                    .allowsHitTesting(false)
            }
            RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous)
                .strokeBorder(isSelected ? Palette.acc : Palette.Editor.overlayOutline, style: StrokeStyle(lineWidth: 2, dash: isSelected ? [] : [5, 4]))
                .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
                .frame(width: rect.width * scale, height: rect.height * scale)
                .contentShape(Rectangle())
        }
        .onTapGesture(coordinateSpace: .named(Self.space)) { location in viewModel.overlays.tapMedia(at: location, in: size) }
        .gesture(
            DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
                .onChanged { value in
                    if drag == nil { beginMoving(media) }
                    let proposed = OverlayPoint(
                        x: Double(rect.midX + value.translation.width) / Double(max(1, size.width)),
                        y: Double(rect.midY + value.translation.height) / Double(max(1, size.height))
                    )
                    let snapped = OverlaysViewModel.snapped(proposed)
                    if (snapped.vertical && !guides.vertical) || (snapped.horizontal && !guides.horizontal) { Haptics.snap() }
                    guides = (snapped.vertical, snapped.horizontal)
                    drag = .media(media.id, offset: CGSize(
                        width: CGFloat(snapped.center.x) * size.width - rect.midX,
                        height: CGFloat(snapped.center.y) * size.height - rect.midY
                    ))
                }
                .onEnded { value in
                    let proposed = OverlayPoint(
                        x: Double(rect.midX + value.translation.width) / Double(max(1, size.width)),
                        y: Double(rect.midY + value.translation.height) / Double(max(1, size.height))
                    )
                    viewModel.overlays.moveMedia(media.id, to: OverlaysViewModel.snapped(proposed).center)
                    endDrag()
                    proxy = nil
                    viewModel.overlays.endOverlayDrag()
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    if pinch?.id != media.id { beginMoving(media) }
                    pinch = (media.id, value.magnification)
                }
                .onEnded { value in
                    viewModel.overlays.resizeMedia(media.id, by: Double(value.magnification))
                    pinch = nil
                    proxy = nil
                    viewModel.overlays.endOverlayDrag()
                }
        )
        .position(x: rect.midX + offset.width, y: rect.midY + offset.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(media.kind == .photo ? Text("Photo") : Text("Video"))
        .accessibilityHint(
            isSelected ? Text("Drag to move, pinch to resize, or use the actions. Tap where another overlaps to pick it.") : Text("Tap to select")
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { viewModel.overlays.tapMedia(at: CGPoint(x: rect.midX, y: rect.midY), in: size) }
        .accessibilityActions { placingActions(.media(media.id)) }
        .accessibilityIdentifier("edit.mediaHandle")
    }

    /// A finger started moving or pinching a photo or video: it's picked, the video leaves it out and its picture follows.
    private func beginMoving(_ media: MediaOverlay) {
        viewModel.player.pause()
        if viewModel.selection != .media(media.id) { viewModel.selection = .media(media.id) }
        viewModel.overlays.beginOverlayDrag(.media(media.id))
        // The second of the file showing now (the part picked, and what the cuts took out, count).
        let local = media.fileTime(at: viewModel.player.currentTime, in: viewModel.edit.timeline) ?? media.startInFile
        Task {
            let image = await thumbnails.picture(
                of: EditMediaFiles.url(for: media.fileName), isVideo: media.kind == .video, at: local, maxPixelSize: 720
            )
            if let image, viewModel.overlays.draggedOverlay == .media(media.id) { proxy = (media.id, image) }
        }
    }
}
