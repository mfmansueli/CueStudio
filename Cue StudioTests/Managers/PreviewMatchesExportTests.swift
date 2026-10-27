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
            let sounds = RecordingSoundCache()
            let preview = try await EditRenderRequest.prepare(
                source: take, edit: edit, purpose: .editorPreview(rendersCurveSound: true), sounds: sounds
            ).build()
            let export = try await EditRenderRequest.prepare(
                source: take, edit: edit, purpose: .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30), sounds: sounds
            ).build()
            let leadIn = edit.timeline.reachableLeadIn
            #expect(leadIn > 0.5)
            for time in feature.times {
                let shown = try await RenderParity.frame(preview.asset, composition: preview.videoComposition, at: leadIn + time)
                let written = try await RenderParity.frame(export.asset, composition: export.videoComposition, at: time)
                let difference = try RenderParity.meanDifference(shown, written, size: size)
                #expect(difference < 2, "\(feature.rawValue) at \(time) s: \(difference)")
            }
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
            return try await MovingFootage.make(seconds: 4, width: 360, height: 640, motion: motion)
        }

        private static let facePath: @Sendable (Int) -> CGPoint = { index in CGPoint(x: 180, y: 140 + Double(min(index, 90)) * 3) }

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
         text, textEffects, turnedText, captions, stabilize, followFace, blurArea

    var testDescription: String { rawValue }

    /// Edited seconds compared.
    var times: [TimeInterval] {
        switch self {
        case .shortClipTransition: [0.2, 0.27, 0.36]
        // Around the cut at 0.95 s, never on it: exactly there, which side shows depends on the last bit of a sum.
        case .slide, .zoomTransition, .flash, .fade, .push, .wipe, .blur, .punch: [0.85, 0.92, 1.0]
        // Sped up, the edit is 2 s.
        case .speed: [0.4, 1.2, 1.8]
        // On their way in, read, on their way out.
        case .textEffects: [0.35, 0.6, 1.4, 2.6, 2.75]
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
