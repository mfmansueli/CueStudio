//
//  PrompterPreviewCard.swift
//  Cue Studio
//

import SwiftUI

/// "PREVIEW": the top of this iPhone's screen in Selfie mode, as the recorder lays it out, scaled down to fit the card. The same
/// `ReadingLayout` places the reading line under the camera (where the creator put it, or the recommended 118 pt) and the text window
/// round it, the creator's width and height; the line spans the screen as in the recorder, past the window's sides. The window is dark
/// and blurred over a stand-in for the camera; the text is the prompter's own (`PrompterParagraphs`: font, size, spacing, alignment,
/// colour, margins, cues), mirrored or flipped as set, the words already read fading above the line. It scrolls at the chosen speed, so a
/// faster or slower pace shows too. Reduce Motion: it stands still.
struct PrompterPreviewCard: View {
    let settings: PrompterSettings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    /// One copy of the sample's height, measured: the scroll loops over it.
    @State private var copyHeight: CGFloat = 0

    /// The card's height; the text window is scaled to fill it (owner, 02/11/2026: the window looked tiny in the phone).
    static let height: CGFloat = 272
    /// Around the window (and the line past its sides), so its edges and the line's ends show.
    private static let focusMargin = CGSize(width: 10, height: 14)
    /// The camera seen under the window, in screen points.
    private static let cameraBelow: CGFloat = 24
    /// The Dynamic Island, drawn where the lens is, so the line's distance under the camera reads.
    private static let island = CGSize(width: 124, height: 36)
    /// A few lines of a real script, with a cue, so the cues setting shows too. In the interface's language, cues included.
    private static let sample = [
        String(localized: "Okay, real talk. [pause] Three tiny habits completely changed my mornings."),
        String(localized: "One: no phone for the first twenty minutes. I leave it in the kitchen."),
        String(localized: "Two: one glass of water before coffee. [smile] It sounds silly. It works."),
        String(localized: "Three: I write down the one thing that matters today."),
    ]

    /// This iPhone's screen and its top inset (the Dynamic Island or the notch), as the recorder measures them.
    private var metrics: SelfieScreenMetrics {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let size = scene?.screen.bounds.size ?? SelfieScreenMetrics().screen
        let top = scene?.windows.first?.safeAreaInsets.top ?? SelfieScreenMetrics().topInset
        let design = SelfieScreenMetrics()
        return SelfieScreenMetrics(
            screen: size, topInset: top, topBarBottom: top + (design.topBarBottom - design.topInset),
            toolbarTop: size.height - (design.screen.height - design.toolbarTop)
        )
    }

    /// Where the recorder puts the line and the window on this screen, with these settings.
    private var layout: ReadingLayout {
        ReadingLayout(
            metrics: metrics, isFrontCamera: true, frameRect: .zero, lineOffset: settings.readingLineOffset,
            windowHeight: settings.textWindowHeight, readingWidth: settings.readingWidth
        )
    }

    private var fontSize: Double { settings.size }
    private var lineHeight: CGFloat { CGFloat(fontSize * settings.lineSpacing) }
    private var gap: CGFloat { CGFloat(fontSize * settings.lineSpacing * 0.75) }

    var body: some View {
        let layout = layout
        let screenSize = CGSize(width: layout.screenWidth, height: layout.windowRect.maxY + Self.cameraBelow)
        let focus = focusRect(layout)
        GeometryReader { proxy in
            // The window fills the card: the screen is scaled to the window (and the line's ends), not to its whole top; the camera
            // and the Dynamic Island show where they fall in that frame.
            let scale = min(proxy.size.width / max(1, focus.width), proxy.size.height / max(1, focus.height))
            screen(layout)
                .frame(width: screenSize.width, height: screenSize.height)
                .scaleEffect(scale, anchor: .topLeading)
                .offset(
                    x: (proxy.size.width - focus.width * scale) / 2 - focus.minX * scale,
                    y: (proxy.size.height - focus.height * scale) / 2 - focus.minY * scale
                )
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(height: Self.height)
        // The camera fills the whole card, so the scaled screen melts into it (no phone outline): the look of the preview stays.
        .background { cameraScene }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .overlay(alignment: .topLeading) {
            Text("PREVIEW")
                .hudFont()
                .interfaceTracking(1)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Palette.bg.opacity(0.7), in: Capsule())
                .padding(10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview of the prompter"))
        .accessibilityIdentifier("settings.prompterPreview")
    }

    /// The part of the screen the card shows: the window and the reading line's span, with a margin.
    private func focusRect(_ layout: ReadingLayout) -> CGRect {
        let rect = layout.windowRect
        let span = layout.lineSpan
        let minX = min(rect.minX, span.lowerBound) - Self.focusMargin.width
        let maxX = max(rect.maxX, span.upperBound) + Self.focusMargin.width
        return CGRect(x: minX, y: rect.minY - Self.focusMargin.height, width: maxX - minX, height: rect.height + 2 * Self.focusMargin.height)
    }

    /// The top of the screen at its real size: the camera, the Dynamic Island, the window and the line where the recorder puts them.
    private func screen(_ layout: ReadingLayout) -> some View {
        let rect = layout.windowRect
        let span = layout.lineSpan
        // The camera is the card's own background (one scene, no seam where the scaled screen ends).
        return ZStack(alignment: .topLeading) {
            Color.clear
            Capsule()
                .fill(.black)
                .frame(width: Self.island.width, height: Self.island.height)
                .position(x: layout.screenWidth / 2, y: layout.lensY)
            window(lead: layout.lead, size: rect.size)
                .position(x: rect.midX, y: rect.midY)
            if settings.showsGuide {
                ReadingGuide(level: nil, showsParticles: false, isCalm: true)
                    .frame(width: span.upperBound - span.lowerBound)
                    .position(x: (span.lowerBound + span.upperBound) / 2, y: layout.lineY)
            }
        }
    }

    /// The stand-in for the camera: a dim room with a warm light where a face would be.
    private var cameraScene: some View {
        LinearGradient(colors: [Palette.Camera.previewSceneTop, Palette.Camera.previewSceneBottom], startPoint: .top, endPoint: .bottom)
            .overlay {
                RadialGradient(colors: [Palette.Camera.previewSceneLight, .clear], center: UnitPoint(x: 0.5, y: 0.85), startRadius: 0, endRadius: 220)
            }
    }

    /// The window as the recorder draws it: dark and blurred over the camera, the text scrolling under the reading line (`lead` from the
    /// window's top). Sized before it is clipped, so nothing of it reaches past its own box.
    private func window(lead: CGFloat, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        return TimelineView(.animation(paused: reduceMotion)) { context in
            VStack(spacing: gap) {
                PrompterParagraphs(paragraphs: Self.sample, settings: settings, fontSize: fontSize)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { copyHeight = $0 }
                PrompterParagraphs(paragraphs: Self.sample, settings: settings, fontSize: fontSize)
            }
            .shadow(color: Palette.textShadow, radius: 1.5, x: 0, y: 1)
            .offset(y: lead - lineHeight / 2 - scrolled(at: context.date))
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .scaleEffect(x: settings.isMirrored ? -1 : 1, y: settings.isFlippedVertically ? -1 : 1)
        .clipped()
        .mask { LinearGradient(stops: fadeStops(lead: lead, height: size.height), startPoint: .top, endPoint: .bottom) }
        .background {
            ZStack {
                let blur = CameraBlurLevel(amount: settings.cameraBlur)
                if blur != .off {
                    Rectangle().fill(.ultraThinMaterial).opacity(blur.strength)
                }
                Rectangle().fill(Color.black.opacity(settings.backgroundOpacity))
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.Camera.panelBorder, lineWidth: 0.5))
    }

    /// How far the text has scrolled: one copy of the sample in the time it takes to read it at the chosen speed, then round again.
    private func scrolled(at date: Date) -> CGFloat {
        guard !reduceMotion, copyHeight > 0 else { return 0 }
        let seconds = max(1, ReadTime.seconds(for: Self.sample.joined(separator: " "), speed: settings.speed))
        let loop = copyHeight + gap
        let travelled = date.timeIntervalSince(start) / seconds * Double(loop)
        return CGFloat(travelled.truncatingRemainder(dividingBy: Double(loop)))
    }

    /// As in the recorder: what was read fades above the line, the bottom edge melts away.
    private func fadeStops(lead: CGFloat, height: CGFloat) -> [Gradient.Stop] {
        let fadeEnd = max(0, lead - lineHeight * 0.9) / max(1, height)
        return [
            .init(color: .black.opacity(0.3), location: 0),
            .init(color: .black, location: min(0.8, fadeEnd)),
            .init(color: .black, location: 0.84),
            .init(color: .clear, location: 1),
        ]
    }
}
