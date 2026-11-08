//
//  PreviewMatchesExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// What the editor's preview shows is what the export writes, tool by tool: both are prepared by one request
    /// (`EditRenderRequest`) and drawn by one composition, the preview with its first and last clips grown to the whole
    /// recording (`EditTimeline.reachable`). Every edit here trims both ends, so the preview's frames sit `reachableLeadIn`
    /// later than the export's. The compositions are compared frame by frame without encoding (the encoded run is
    /// `EditorExportMatchesPreviewTests`).
    @MainActor
    @Suite("The preview is the export, tool by tool", .serialized, .timeLimit(.minutes(10)))
    struct PreviewMatchesExportTests {
        private let size = CGSize(width: 180, height: 320)

        @Test(arguments: RenderFeature.allCases)
        func thePreviewIsTheExport(_ feature: RenderFeature) async throws {
            let take = try await footage(for: feature)
            defer {
                MotionAnalysisStore.remove(forRecording: take)
                try? FileManager.default.removeItem(at: take)
            }
            let edit = try await edit(for: feature, take: take)
            // A support or a masked window: its video was linked in for this edit.
            defer { EditMediaFiles.remove(edit.mediaFileNames) }
            let sounds = RecordingSoundCache()
            let preview = try await EditRenderRequest.prepare(
                source: take, edit: edit, purpose: .editorPreview(rendersCurveSound: true), sounds: sounds
            ).build()
            let export = try await EditRenderRequest.prepare(
                source: take, edit: edit, purpose: .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30), sounds: sounds
            ).build()
            let leadIn = edit.timeline.reachableLeadIn
            // The 0.6 s trimmed off the start, played at the curve's speed there.
            #expect(leadIn > (feature == .speedCurve ? 0.2 : 0.5))
            for time in feature.times {
                let shown = try await RenderParity.frame(preview.asset, composition: preview.videoComposition, at: leadIn + time)
                let written = try await RenderParity.frame(export.asset, composition: export.videoComposition, at: time)
                let difference = try RenderParity.meanDifference(shown, written, size: size)
                #expect(difference < 2, "\(feature.rawValue) at \(time) s: \(difference)")
            }
        }

        /// A video laid over the take's own seconds (not following the cuts) from 0.2 s, with the take's start trimmed to 0.6 s: the
        /// preview plays the trimmed start too, so at the take's second 1.05 the video is at its 0.85; the file, which starts at
        /// 0.6, shows the video from the second it had reached there (`MediaOverlay.pieces`), so both show the same frame.
        @Test func aVideoPinnedToTrimmedSecondsShowsTheSameFrameInPreviewAndFile() async throws {
            let take = try await footage(for: .mask)
            defer { try? FileManager.default.removeItem(at: take) }
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.timeline.trimStart(to: 0.6)
            edit.timeline.trimEnd(to: 3.6)
            var window = MediaOverlay(
                kind: .video, fileName: try await supportVideo(), aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 0.2, end: 2.8)
            )
            window.layout = .fullFrame
            window.mask = MediaMask(shape: .circle, placement: MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.3), width: 0.5, height: 0.5 * 9 / 16))
            edit.media = [window]
            defer { EditMediaFiles.remove(edit.mediaFileNames) }
            let sounds = RecordingSoundCache()
            let preview = try await EditRenderRequest.prepare(
                source: take, edit: edit, purpose: .editorPreview(rendersCurveSound: true), sounds: sounds
            ).build()
            let export = try await EditRenderRequest.prepare(
                source: take, edit: edit, purpose: .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30), sounds: sounds
            ).build()
            let leadIn = edit.timeline.reachableLeadIn
            let shown = try await RenderParity.frame(preview.asset, composition: preview.videoComposition, at: leadIn + 0.45)
            let written = try await RenderParity.frame(export.asset, composition: export.videoComposition, at: 0.45)
            let difference = try RenderParity.meanDifference(shown, written, size: size)
            #expect(difference < 2, "\(difference)")
        }

        /// The effects compared above are drawn at all: a frame with them is not the frame without them.
        @Test func theTextEffectsAreDrawn() async throws {
            let take = try await footage(for: .textEffects)
            defer { try? FileManager.default.removeItem(at: take) }
            let styled = try await edit(for: .textEffects, take: take)
            var plain = styled
            plain.texts = []
            let sounds = RecordingSoundCache()
            for time in [0.6, 1.4] {
                var frames: [CGImage] = []
                for edit in [styled, plain] {
                    let export = try await EditRenderRequest.prepare(
                        source: take, edit: edit, purpose: .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30), sounds: sounds
                    ).build()
                    frames.append(try await RenderParity.frame(export.asset, composition: export.videoComposition, at: time))
                }
                let difference = try RenderParity.meanDifference(frames[0], frames[1], size: size)
                #expect(difference > 2, "at \(time) s: \(difference)")
            }
        }

        /// Grain sliding a little every frame; a camera shaking for Stabilize; a square walking down for Follow face.
        private func footage(for feature: RenderFeature) async throws -> URL {
            let motion: MovingFootage.Motion = switch feature {
            case .stabilize:
                .init(background: { index in (CGPoint(x: 9 * sin(Double(index) * 1.7), y: 6 * cos(Double(index) * 2.1)), 0) })
            case .followFace:
                .init(background: { index in (CGPoint(x: Double(index), y: 0), 0) }, square: Self.facePath, squareSide: 60)
            default:
                .init(background: { index in (CGPoint(x: Double(index) * 2, y: Double(index)), 0) })
            }
            // Punch in on cuts needs pixels to zoom into (at 640 a zoom is held at 1×, `ZoomAnchor.minimumPixels`): 720 allows 1.33×.
            if feature == .cutZoom { return try await MovingFootage.make(seconds: 4, width: 720, height: 1280, motion: motion) }
            return try await MovingFootage.make(seconds: 4, width: 360, height: 640, motion: motion)
        }

        /// The tools laid over the take or that reshape its time: Background, Skin, Mask, split screen and speed curves.
        private func addLayer(_ feature: RenderFeature, to edit: inout TakeEdit) async throws {
            switch feature {
            case .speedCurve:
                var clip = try #require(edit.timeline.segments.first)
                clip.speedCurve = SpeedCurvePreset.hero.curve
                _ = edit.timeline.replaceSegment(clip)
            case .background:
                // The person cut out of the take (the made-up footage has none: its whole picture is background) and blurred.
                edit.backgrounds = [RecordingBackground(sourceID: nil, effect: BackgroundEffect(style: .blur, blur: 0.8))]
            case .backgroundKey:
                var effect = BackgroundEffect(style: .color, cutout: .colorKey)
                effect.color = .white
                edit.backgrounds = [RecordingBackground(sourceID: nil, effect: effect)]
            case .skin:
                // Without a face in the footage, Skin must leave the picture alike in both (the face itself is checked on the
                // iPhone, `SkinSmoothingDeviceTests`).
                edit.skin = SkinLook(smoothing: SkinSmoothing(amount: 100, texture: 50), faceLight: 100, antiShine: 100)
            case .mask:
                var window = MediaOverlay(
                    kind: .video, fileName: try await supportVideo(), aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 0.2, end: 2.8)
                )
                window.layout = .fullFrame
                // Following the cuts: the mask's drawing is compared here (a video pinned to seconds the trim cut into is
                // `aVideoPinnedToTrimmedSecondsShowsTheSameFrameInPreviewAndFile`).
                window.followsCuts = true
                window.mask = MediaMask(shape: .circle, placement: MaskPlacement(center: OverlayPoint(x: 0.5, y: 0.3), width: 0.5, height: 0.5 * 9 / 16))
                edit.media = [window]
            case .splitScreen:
                edit.splitScreen.setLayout(SplitLayout())
                var support = MediaOverlay(
                    kind: .video, fileName: try await supportVideo(), aspect: 9.0 / 16, mediaDuration: 4, span: TimeSpan(start: 0.2, end: 2.8)
                )
                support.layout = .split
                support.followsCuts = true
                edit.media = [support]
            default:
                break
            }
        }

        /// Another moving video, linked into the edit's files (removed after the test).
        private func supportVideo() async throws -> String {
            let video = try await MovingFootage.make(
                seconds: 4, width: 360, height: 640, motion: .init(background: { index in (CGPoint(x: -Double(index) * 3, y: 0), 0) })
            )
            defer { try? FileManager.default.removeItem(at: video) }
            return try EditMediaFiles.link(video)
        }

        private static let facePath: @Sendable (Int) -> CGPoint = { index in CGPoint(x: 180, y: 140 + Double(min(index, 90)) * 3) }

        /// One face held left of the middle and high for the whole recording, the way a zoom grows toward it (`FaceZoomFocus`).
        private static func steadyFace(width: Double, height: Double) -> MotionAnalysis {
            var analysis = MotionAnalysis(duration: 4, width: width, height: height)
            let face = NormalizedBox(center: CGPoint(x: 0.3, y: 0.3), width: 0.25, height: 0.14)
            analysis.subjects = stride(from: 0.0, to: 4, by: 0.1).map { SubjectSample(time: $0, faces: [face], bodies: []) }
            analysis.analyzedUntil = 4
            return analysis
        }

        /// Punch in on cuts is drawn at all, toward the face: the punched clip's frame is not the frame without it, and not the
        /// frame zoomed from the middle.
        @Test func thePunchInIsDrawnTowardTheFace() async throws {
            let take = try await footage(for: .cutZoom)
            defer {
                MotionAnalysisStore.remove(forRecording: take)
                try? FileManager.default.removeItem(at: take)
            }
            let punched = try await edit(for: .cutZoom, take: take)
            var plain = punched
            plain.cutZoom = nil
            plain.phraseZooms = []
            let sounds = RecordingSoundCache()
            var frames: [CGImage] = []
            for edit in [punched, plain] {
                let export = try await EditRenderRequest.prepare(
                    source: take, edit: edit, purpose: .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30), sounds: sounds
                ).build()
                frames.append(try await RenderParity.frame(export.asset, composition: export.videoComposition, at: 1.4))
            }
            #expect(try RenderParity.meanDifference(frames[0], frames[1], size: size) > 2)
            // Without the face the same punch-in grows from the middle: another frame.
            MotionAnalysisStore.remove(forRecording: take)
            let centred = try await EditRenderRequest.prepare(
                source: take, edit: punched, purpose: .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30), sounds: sounds
            ).build()
            let middle = try await RenderParity.frame(centred.asset, composition: centred.videoComposition, at: 1.4)
            #expect(try RenderParity.meanDifference(frames[0], middle, size: size) > 2)
        }

        /// An edit with both ends trimmed (0.6 s off the start, 0.4 s off the end) and the tool on.
        private func edit(for feature: RenderFeature, take: URL) async throws -> TakeEdit {
            var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
            edit.voiceEnhancement = .off
            edit.timeline.trimStart(to: 0.6)
            edit.timeline.trimEnd(to: 3.6)
            switch feature {
            case .look:
                edit.contrast = 25
                edit.warmth = 20
                edit.filter = .warmFilm
            case .crop:
                edit.aspect = .square
                edit.cropOffset = -0.5
            case .fit:
                edit.aspect = .landscape
                edit.cropFit = .fit
            case .clipZoom:
                var clip = try #require(edit.timeline.segments.first)
                clip.zoom = .pushIn
                clip.zoomAmount = 1
                _ = edit.timeline.replaceSegment(clip)
            case .shortClipTransition:
                // A first clip of 0.3 s: the transition has less room than in the clip grown to the recording's start. Half a
                // second is cut out at the seam, so the two sides show different frames.
                _ = edit.timeline.removeEdited(0.3...0.8)
                _ = edit.timeline.setTransition(.dissolve, atJoin: 1)
            case .slide, .zoomTransition, .flash, .fade, .push, .wipe, .blur, .punch:
                _ = edit.timeline.removeEdited(0.95...1.45)
                _ = edit.timeline.setTransition(try #require(feature.transition), atJoin: 1)
            case .speed:
                _ = edit.timeline.split(atEdited: 1)
                _ = edit.timeline.setSpeed(2, forSegmentAt: 1)
            case .speedCurve, .background, .backgroundKey, .skin, .mask, .splitScreen:
                try await addLayer(feature, to: &edit)
            case .text:
                var title = TextOverlay(role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: TimeSpan(start: 0.2, end: 2.8))
                title.text = "5 comidas de SP"
                edit.texts = [title]
            case .textEffects:
                // Three effects on their way in, read and on their way out, one with an emoji and accents.
                let span = TimeSpan(start: 0.2, end: 2.8)
                var gold = TextOverlay(role: .title, look: TypePreset.gold.look(for: .title), preset: .gold, span: span)
                gold.text = "Ação 👩🏽‍💻"
                var wave = TextOverlay(role: .title, look: TypePreset.wave.look(for: .title), preset: .wave, span: span)
                wave.text = "Onda"
                wave.center = OverlayPoint(x: 0.5, y: 0.78)
                var neon = TextOverlay(role: .title, look: TypePreset.neon.look(for: .title), preset: .neon, span: span)
                neon.text = "Neon"
                neon.center = OverlayPoint(x: 0.5, y: 0.22)
                edit.texts = [gold, wave, neon]
            case .turnedText:
                // Resized as a whole, turned, its effect's motion off, moved and turned again by its keyframes.
                var title = TextOverlay(role: .title, look: TypePreset.pop3D.look(for: .title), preset: .pop3D, span: TimeSpan(start: 0.2, end: 2.8))
                title.text = "Volume pop em duas linhas"
                title.block = TextBlock(width: 150, size: title.size)
                title.size *= 1.3
                title.rotation = 0.3
                title.effect?.motion = .still
                title.keyframes = [
                    OverlayKeyframe(time: 0.2, center: OverlayPoint(x: 0.4, y: 0.4), rotation: -0.2),
                    OverlayKeyframe(time: 2, center: OverlayPoint(x: 0.6, y: 0.6), scale: 1.3, rotation: 0.5),
                ]
                edit.texts = [title]
            case .captions:
                edit.showsCaptions = true
                edit.captionCollection = CaptionSettings(theme: .pop)
                edit.captions = [
                    CaptionCue(text: "Massa fina, muito recheio", start: 0.8, end: 2.2),
                    CaptionCue(text: "e o forno a lenha", start: 2.2, end: 3.4),
                ]
            case .stabilize:
                var clip = try #require(edit.timeline.segments.first)
                clip.stabilization = .standard
                _ = edit.timeline.replaceSegment(clip)
                // The preview draws with the analyses ready; the export would make it.
                let analysis = try await MotionAnalyzer().analyze(videoAt: take, continuing: nil, shouldStop: { false }, checkpoint: { _ in })
                MotionAnalysisStore.save(analysis, forRecording: take)
            case .blurArea:
                // A pixelated area moving across the recording, under a square crop.
                edit.aspect = .square
                var region = BlurRegion(
                    target: .recording(nil), span: TimeSpan(start: 0.5, end: 3.5), box: NormalizedBox(x: 0.3, y: 0.3, width: 0.3, height: 0.15)
                )
                region.keyframes = [
                    BlurKeyframe(time: 0.5, box: NormalizedBox(x: 0.1, y: 0.3, width: 0.3, height: 0.15)),
                    BlurKeyframe(time: 3.5, box: NormalizedBox(x: 0.6, y: 0.5, width: 0.3, height: 0.15)),
                ]
                edit.blurRegions = [region]
            case .cutZoom:
                // The second clip punched in at Strong toward a face left of the middle, a phrase zoom over it on top (together
                // held at what the 720 pixels allow).
                _ = edit.timeline.removeEdited(0.95...1.45)
                edit.cutZoom = CutZoom(strength: .strong)
                edit.phraseZooms = [PhraseZoom(span: TimeSpan(start: 2.8, end: 3.5), strength: .strong)]  // Edited 1.7 to 2.4.
                MotionAnalysisStore.save(Self.steadyFace(width: 720, height: 1280), forRecording: take)
            case .followFace:
                edit.aspect = .square
                edit.faceFollow = FaceFollow(pace: .quick)
                var analysis = MotionAnalysis(duration: 4, width: 360, height: 640)
                analysis.subjects = stride(from: 0.0, to: 4, by: 0.1).map { time in
                    let center = Self.facePath(Int((time * 30).rounded()))
                    let face = NormalizedBox(center: CGPoint(x: center.x / 360, y: center.y / 640), width: 60.0 / 360, height: 60.0 / 640)
                    return SubjectSample(time: time, faces: [face], bodies: [])
                }
                analysis.analyzedUntil = 4
                MotionAnalysisStore.save(analysis, forRecording: take)
            }
            return edit
        }
    }
}

/// The tools `PreviewMatchesExportTests` compares.
enum RenderFeature: String, CaseIterable, CustomTestStringConvertible {
    case look, crop, fit, clipZoom, shortClipTransition, slide, zoomTransition, flash, fade, push, wipe, blur, punch, speed,
         speedCurve, text, textEffects, turnedText, captions, stabilize, followFace, blurArea, background, backgroundKey, skin, mask,
         splitScreen, cutZoom

    var testDescription: String { rawValue }

    /// Edited seconds compared.
    var times: [TimeInterval] {
        switch self {
        case .shortClipTransition: [0.2, 0.27, 0.36]
        // Around the cut at 0.95 s, never on it: exactly there, which side shows depends on the last bit of a sum.
        case .slide, .zoomTransition, .flash, .fade, .push, .wipe, .blur, .punch: [0.85, 0.92, 1.0]
        // Sped up, the edit is 2 s.
        case .speed: [0.4, 1.2, 1.8]
        // Slow in the middle, fast at the ends: within the shortest the curve can make.
        case .speedCurve: [0.3, 0.9, 1.5]
        // A video over the take: halfway between two frames of both (on a frame's edge, which of the two shows depends on the last
        // bit of a sum, in the take and in the video over it alike).
        case .mask, .splitScreen: [0.45, 1.45, 2.45]
        // On their way in, read, on their way out.
        case .textEffects: [0.35, 0.6, 1.4, 2.6, 2.75]
        // As filmed, punched in, punched in with the phrase zoom over it.
        case .cutZoom: [0.4, 1.4, 2.1]
        default: [0.4, 1.4, 2.6]
        }
    }

    var transition: EditTransition? {
        switch self {
        case .slide: .slide
        case .zoomTransition: .zoom
        case .flash: .flash
        case .fade: .fade
        case .push: .push
        case .wipe: .wipe
        case .blur: .blur
        case .punch: .punch
        case .shortClipTransition: .dissolve
        default: nil
        }
    }
}
