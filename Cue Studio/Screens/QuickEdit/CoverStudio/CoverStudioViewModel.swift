//
//  CoverStudioViewModel.swift
//  Cue Studio
//

import Foundation
import UIKit

/// Cover Studio: a cover made in five steps (picture, template, title, graphics, finish) on a canvas where everything is
/// moved with a finger. It works on its own copy of the cover with its own undo and redo; Done hands the cover to the editor as
/// one undo step there, Cancel leaves the editor's cover as it was. The canvas shows the cover drawn by the same renderer as
/// the saved image (`CoverCompositionRenderer`), drawn again after every change, the newest change winning, so a gesture
/// shows its result while the finger moves.
@MainActor
@Observable
final class CoverStudioViewModel: Identifiable {
    let id = UUID()

    /// Width of the canvas's drawing in pixels: sharp on an iPhone's canvas, quick to draw again while a finger moves.
    static let canvasWidth: CGFloat = 720
    /// Width of a template's thumbnail in pixels.
    static let thumbnailWidth: CGFloat = 180

    // MARK: State

    /// The cover being made.
    private(set) var cover: VideoCover
    var step: CoverStudioStep
    var selection: CoverStudioSelection?
    var cropGuide: CoverCropGuide = .none
    /// Before/after: the Picture step works on the after half.
    var editsSecondPicture = false
    /// The cover as drawn now.
    private(set) var rendered: UIImage?
    /// Each template as this cover would look in it.
    private(set) var thumbnails: [CoverTemplate: UIImage] = [:]
    /// Whether a person was found for Text behind me and Outline me; nil until looked for.
    private(set) var personFound: Bool?
    private(set) var isLoadingPicture = false
    /// The picture couldn't be read (a recording gone, a damaged photo).
    private(set) var pictureFailed = false
    private(set) var isImporting = false
    /// A guide shows while something is dragged: the middle across, and which height it stuck to.
    private(set) var guides: (vertical: Bool, horizontal: Double?) = (false, nil)
    /// A message for a moment (a photo that couldn't be read).
    var notice: String?
    /// The editor had a cover when the studio opened: Finish offers Remove cover.
    let hadCover: Bool
    /// Remove cover was asked: Done takes the cover away.
    private(set) var removesCover = false

    // MARK: History

    private var past: [VideoCover] = []
    private var future: [VideoCover] = []
    /// The cover when a gesture began: the gesture is one undo step.
    @ObservationIgnored private var gestureBase: VideoCover?
    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    // MARK: Context

    let edit: TakeEdit
    let videoURL: URL
    /// The creator's handle, for the series and the handle graphic.
    let handle: String
    /// Titles Cue suggests from the take's own words.
    let suggestions: [String]
    /// Width over height of the cover (the take's format).
    let aspect: Double
    private(set) var myStyle: CoverStyle?
    @ObservationIgnored private let pictures: CoverPicturing
    @ObservationIgnored private let importer: EditMediaImporting
    @ObservationIgnored private let styles: TextStyleStoring
    /// Files copied in while the studio was open (photos), for the editor to keep or clean up.
    @ObservationIgnored private(set) var importedFiles: Set<String> = []

    // MARK: Caches

    @ObservationIgnored private var mainPicture: (source: CoverSource, image: UIImage)?
    @ObservationIgnored private var secondPicture: (source: CoverSource, image: UIImage)?
    @ObservationIgnored private var cutout: (key: CutoutKey, cutout: CoverDesignRenderer.Cutout?)?
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    /// Reading the picture a change asks for; a newer change cancels it (scrubbing the strip asks for many).
    @ObservationIgnored private var pictureTask: Task<Void, Never>?
    /// The last frame of the edit the cover showed (edited seconds), so going back from a photo to the video finds it.
    @ObservationIgnored var lastFrameTime: TimeInterval?
    @ObservationIgnored private var thumbnailTask: Task<Void, Never>?
    @ObservationIgnored private var renderGeneration = 0

    private struct CutoutKey: Equatable {
        let main: CoverSource
        let second: CoverSource?
        let framing: CoverFraming
        let split: CoverSplit?
        let outlined: Bool
    }

    /// `cover`: the editor's cover (made before Cover Studio or in it), or nil to make a new one from `frame`.
    init(
        cover: VideoCover?, frame: CoverFrame, edit: TakeEdit, videoURL: URL, handle: String, suggestions: [String],
        pictures: CoverPicturing, importer: EditMediaImporting, styles: TextStyleStoring
    ) {
        self.edit = edit
        self.videoURL = videoURL
        self.handle = handle
        self.suggestions = suggestions
        self.pictures = pictures
        self.importer = importer
        self.styles = styles
        aspect = edit.aspect.widthOverHeight
        hadCover = cover != nil
        let myStyle = styles.myCoverStyle
        self.myStyle = myStyle
        if var existing = cover {
            if existing.composition == nil { existing.composition = CoverComposition(legacy: existing) }
            self.cover = existing
            step = .text
        } else {
            var made = VideoCover(source: .clipFrame(frame))
            made.title = suggestions.first ?? ""
            made.composition = myStyle?.composition(title: made.title, handle: handle, episode: 1)
                ?? CoverComposition.make(.educational, title: made.title, handle: handle)
            self.cover = made
            step = .image
        }
    }

    var composition: CoverComposition {
        cover.composition ?? CoverComposition.make(.educational, title: cover.title)
    }

    /// Size of the cover in canvas pixels.
    var canvasSize: CGSize {
        CGSize(width: Self.canvasWidth, height: (Self.canvasWidth / CGFloat(aspect)).rounded())
    }

    // MARK: - Opening

    /// Reads the pictures and draws the cover and the templates.
    func start() async {
        if !pictureIsPhoto { lastFrameTime = pictureEditedTime }
        await loadPictures()
        scheduleRender()
        scheduleThumbnails()
    }

    func loadPictures() async {
        isLoadingPicture = true
        defer { isLoadingPicture = false }
        let source = cover.source
        if mainPicture?.source != source {
            let image = await pictures.picture(for: source, videoURL: videoURL, edit: edit)
            // A newer frame was asked for meanwhile: it wins, never this one.
            guard !Task.isCancelled, cover.source == source else { return }
            guard let image else {
                pictureFailed = true
                return
            }
            mainPicture = (source, image)
        }
        pictureFailed = false
        if let second = composition.activeSplit?.source, secondPicture?.source != second {
            let image = await pictures.picture(for: second, videoURL: videoURL, edit: edit)
            guard !Task.isCancelled, composition.activeSplit?.source == second else { return }
            secondPicture = image.map { (second, $0) }
        }
    }

    // MARK: - Changes

    /// A change undo takes back in one step.
    func change(_ update: (inout VideoCover) -> Void) {
        var next = cover
        update(&next)
        guard next != cover else { return }
        if gestureBase == nil {
            past.append(cover)
            future = []
        }
        cover = next
        coverDidChange()
    }

    /// A change of the composition, one undo step.
    func changeComposition(_ update: (inout CoverComposition) -> Void) {
        change { cover in
            var composition = cover.composition ?? CoverComposition.make(.educational, title: cover.title)
            update(&composition)
            cover.composition = composition
        }
    }

    /// A finger starts moving something: everything until `endGesture` is one undo step.
    func beginGesture() {
        guard gestureBase == nil else { return }
        gestureBase = cover
    }

    func endGesture() {
        guard let base = gestureBase else { return }
        gestureBase = nil
        guides = (false, nil)
        if base != cover {
            past.append(base)
            future = []
        }
        // Drawn again in full (with the person cut out) now that it stands still.
        scheduleRender()
    }

    var isGesturing: Bool { gestureBase != nil }

    func undo() {
        guard let previous = past.popLast() else { return }
        future.append(cover)
        cover = previous
        coverDidChange(reloadsPictures: true)
    }

    func redo() {
        guard let next = future.popLast() else { return }
        past.append(cover)
        cover = next
        coverDidChange(reloadsPictures: true)
    }

    func showGuides(vertical: Bool, horizontal: Double?) {
        if (vertical && !guides.vertical) || (horizontal != nil && horizontal != guides.horizontal) { Haptics.snap() }
        guides = (vertical, horizontal)
    }

    private func coverDidChange(reloadsPictures: Bool = false) {
        if let id = selection?.itemID, composition.item(id) == nil { selection = nil }
        if reloadsPictures || mainPicture?.source != cover.source || composition.activeSplit?.source != secondPicture?.source {
            pictureTask?.cancel()
            pictureTask = Task {
                await loadPictures()
                guard !Task.isCancelled else { return }
                scheduleRender()
                if !isGesturing { scheduleThumbnails() }
            }
            return
        }
        scheduleRender()
        if !isGesturing { scheduleThumbnails() }
    }

    // MARK: - Drawing

    /// Draws the cover again; a newer change cancels a drawing still going. While a finger moves the person isn't cut out
    /// again (Vision is too slow for every frame): the last cut-out is used when nothing it depends on moved.
    func scheduleRender() {
        renderTask?.cancel()
        guard let main = mainPicture?.image else { return }
        renderGeneration += 1
        let generation = renderGeneration
        let pictures = CoverCompositionRenderer.Pictures(main: main, second: secondPicture?.image)
        let composition = composition
        let title = cover.title
        let size = canvasSize
        let gesturing = isGesturing
        renderTask = Task { [weak self] in
            guard let self else { return }
            var person: CoverDesignRenderer.Cutout?
            if composition.effect.needsPersonMask {
                let key = CutoutKey(
                    main: cover.source, second: composition.activeSplit?.source, framing: composition.framing, split: composition.activeSplit,
                    outlined: composition.effect == .outline
                )
                if let cached = cutout, cached.key == key {
                    person = cached.cutout
                } else if !gesturing {
                    person = await self.pictures.cutout(of: pictures, composition: composition, size: size)
                    guard !Task.isCancelled else { return }
                    cutout = (key, person)
                    personFound = person != nil
                }
            }
            let image = await self.pictures.render(title: title, composition: composition, pictures: pictures, size: size, cutout: person)
            guard !Task.isCancelled, generation == renderGeneration else { return }
            rendered = image
        }
    }

    /// Draws every template with this cover's picture and title, a moment after the last change.
    func scheduleThumbnails() {
        thumbnailTask?.cancel()
        guard let main = mainPicture?.image else { return }
        let pictures = CoverCompositionRenderer.Pictures(main: main, second: secondPicture?.image)
        let current = composition
        let title = cover.title
        let handle = handle
        let size = CGSize(width: Self.thumbnailWidth, height: (Self.thumbnailWidth / CGFloat(aspect)).rounded())
        thumbnailTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            var drawn: [CoverTemplate: UIImage] = [:]
            for template in CoverTemplate.allCases {
                let composition = current.template == template ? current : current.applying(template, title: title, handle: handle)
                drawn[template] = await self.pictures.render(title: title, composition: composition, pictures: pictures, size: size, cutout: nil)
                guard !Task.isCancelled else { return }
            }
            thumbnails = drawn
        }
    }

    // MARK: - Geometry

    /// The title's frame on a canvas of `size` (points, top left), as drawn; nil without words.
    func titleFrame(in size: CGSize) -> CGRect? {
        let layout = CoverCompositionRenderer.titleLayout(title: cover.title, composition: composition, size: size)
        guard !layout.lines.isEmpty || layout.number != nil || layout.kicker != nil else { return nil }
        return layout.bounds
    }

    /// The title doesn't fit even at its smallest size.
    var titleOverflows: Bool {
        CoverCompositionRenderer.titleLayout(title: cover.title, composition: composition, size: canvasSize).overflows
    }

    func itemFrame(_ item: CoverItem, in size: CGSize) -> (center: CGPoint, size: CGSize) {
        let shape = CoverCompositionRenderer.size(of: item, coverSize: size)
        return (CGPoint(x: item.center.x * size.width, y: item.center.y * size.height), shape)
    }

    /// What a tap at `point` on a canvas of `size` lands on, the top first: a graphic, the title, the divider.
    func hit(at point: CGPoint, in size: CGSize) -> CoverStudioSelection? {
        for item in composition.items.reversed() {
            let frame = itemFrame(item, in: size)
            let local = point.applying(
                CGAffineTransform(translationX: -frame.center.x, y: -frame.center.y).concatenating(CGAffineTransform(rotationAngle: -CGFloat(item.rotation)))
            )
            let reach = CGRect(x: -frame.size.width / 2, y: -frame.size.height / 2, width: frame.size.width, height: frame.size.height)
                .insetBy(dx: -12, dy: -12)
            if reach.contains(local) { return .item(item.id) }
        }
        if let title = titleFrame(in: size), title.insetBy(dx: -10, dy: -10).contains(point) { return .title }
        if let split = composition.activeSplit, abs(point.x - split.position * size.width) < 22 { return .divider }
        return nil
    }

    /// A tap on the canvas: picks what's there (and opens its step), or lets go.
    func tap(at point: CGPoint, in size: CGSize) {
        let hit = hit(at: point, in: size)
        Haptics.selection()
        selection = hit
        switch hit {
        case .title: step = .text
        case .item: step = .elements
        case .divider: step = .image
        case nil: break
        }
    }

    /// The pixel size of the cover's picture (or the after half's), once read.
    func pictureImageSize(second: Bool) -> CGSize? {
        second ? (secondPicture?.image.size ?? mainPicture?.image.size) : mainPicture?.image.size
    }

    // MARK: - Finishing

    /// The cover to hand to the editor; nil after Remove cover.
    var finishedCover: VideoCover? { removesCover ? nil : cover }

    /// "Remove cover": the video goes out without one (Done applies it).
    func removeCover() {
        removesCover = true
    }

    func remember(imported name: String) {
        importedFiles.insert(name)
    }

    func setMyStyle(_ style: CoverStyle) {
        styles.myCoverStyle = style
        myStyle = style
    }

    var importing: EditMediaImporting { importer }

    func setImporting(_ importing: Bool) {
        isImporting = importing
    }
}
