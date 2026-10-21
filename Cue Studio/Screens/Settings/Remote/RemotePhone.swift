//
//  RemotePhone.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// One of the two devices of Settings › Remote's scene (`RemoteHero`), drawn at `width` (its height an iPhone's).
/// - The teleprompter: lines of a script rising slowly under the yellow reading line, which runs past its sides as it does in the
///   recorder; the line already read dims above it. While it waits for the other device (`code`), the script fades, the code comes up
///   on white like a printed card, and the reading line shortens to the card and sweeps it up and down: the line becomes the scanner.
/// - The remote: a play button whose halo swells now and then, as if asking for the tap, over a small speed bar.
/// `time` is the scene's clock; with `moves` off (Reduce Motion) everything holds still.
struct RemotePhone: View {
    enum Kind { case prompter, remote }

    let kind: Kind
    let width: CGFloat
    var code: Double = 0
    /// The pairing code's image (`QRCodeView.makeImage`), made once: this view is drawn every frame.
    var codeImage: UIImage?
    let time: TimeInterval
    var moves = true

    /// Seconds for the reading line to sweep the code down and back.
    static let scanPeriod: TimeInterval = 2.8
    /// Seconds for the script to rise one line.
    private static let linePeriod: TimeInterval = 1.6
    /// Seconds between two calls of the remote's play button.
    private static let invitePeriod: TimeInterval = 3.2
    /// The script's lines, as fractions of the screen's width.
    private static let lineWidths: [CGFloat] = [0.62, 0.78, 0.54, 0.72, 0.48, 0.8, 0.6, 0.7]

    private var height: CGFloat { RemoteSceneLayout.height(forWidth: width) }
    private var radius: CGFloat { width * 0.21 }
    private var inset: CGFloat { width * 0.055 }
    private var clock: TimeInterval { moves ? time : 0 }

    var body: some View {
        let body = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            body.fill(Palette.Remote.deviceBody)
            screen
                .clipShape(RoundedRectangle(cornerRadius: radius - inset, style: .continuous))
                .padding(inset)
            Capsule()
                .fill(Palette.Remote.deviceIsland)
                .frame(width: width * 0.33, height: width * 0.095)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, width * 0.085)
            body.strokeBorder(Palette.Remote.deviceRim, lineWidth: 2)
            // The rim catches the light only along the top, as glass does.
            body.strokeBorder(LinearGradient(colors: [Palette.Settings.tileRim, .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
        }
        .frame(width: width, height: height)
        .overlay { if kind == .prompter { readingLine } }
    }

    @ViewBuilder
    private var screen: some View {
        switch kind {
        case .prompter:
            ZStack {
                script.opacity(1 - code)
                if code > 0, let codeImage { codeCard(codeImage) }
            }
        case .remote:
            remoteScreen
        }
    }

    // MARK: - The teleprompter

    /// Where the reading line sits on the screen, as a fraction of the device's height.
    private static let lineAt: CGFloat = 0.5

    /// The script rising a line every `linePeriod`, brightest on the reading line, dimmer above it (read) than below (to come).
    private var script: some View {
        Canvas { context, size in
            let spacing = width * 0.15
            let thickness = max(2.5, width * 0.042)
            let readingY = height * Self.lineAt - inset
            let travelled = CGFloat(clock / Self.linePeriod)
            let rise = travelled.truncatingRemainder(dividingBy: 1) * spacing
            let first = Int(travelled)
            for row in -1...Int(size.height / spacing) + 2 {
                let y = readingY + CGFloat(row) * spacing - rise
                guard y > -thickness, y < size.height + thickness else { continue }
                let widthFraction = Self.lineWidths[abs(row + first) % Self.lineWidths.count]
                let distance = abs(y - readingY) / spacing
                let opacity = distance < 0.5 ? 1 : (y < readingY ? 0.3 : 0.55)
                let bar = CGRect(x: width * 0.08, y: y - thickness / 2, width: size.width * widthFraction * 0.82, height: thickness)
                context.fill(Path(roundedRect: bar, cornerRadius: thickness / 2), with: .color(Palette.Remote.screenText.opacity(opacity)))
            }
        }
    }

    /// The pairing code printed on white, coming up from a little smaller as the script fades.
    private func codeCard(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(width * 0.06)
            .background(Palette.Remote.qrPaper, in: RoundedRectangle(cornerRadius: width * 0.09, style: .continuous))
            .frame(width: width * 0.78, height: width * 0.78)
            .scaleEffect(0.86 + 0.14 * code)
            .opacity(code)
    }

    /// The reading line, past the device's sides with its glow; while the code is up it narrows to the card and sweeps it.
    private var readingLine: some View {
        let restWidth = width * 1.22
        let scanWidth = width * 0.86
        let lineWidth = restWidth + (scanWidth - restWidth) * code
        let cardTop = height / 2 - width * 0.39
        let sweep = moves ? (1 - cos(clock / Self.scanPeriod * 2 * .pi)) / 2 : 0.5
        let scanY = cardTop + width * 0.78 * sweep
        let restY = height * Self.lineAt
        let y = restY + (scanY - restY) * code
        let breath = moves ? 0.82 + 0.18 * sin(clock / CueMotion.Duration.horizonBreath * 2 * .pi) : 1
        return ZStack {
            Capsule().fill(Palette.acc).frame(width: lineWidth, height: 5).blur(radius: 3.5).opacity(0.7 * breath)
            Capsule().fill(Palette.acc).frame(width: lineWidth, height: 1.6)
        }
        .position(x: width / 2, y: y)
        .allowsHitTesting(false)
    }

    // MARK: - The remote

    private var remoteScreen: some View {
        let buttonSize = width * 0.56
        let invite = moves ? (clock / Self.invitePeriod).truncatingRemainder(dividingBy: 1) : 1
        // The halo leaves in the first third of each call, then the button rests.
        let halo = min(1, invite * 3)
        return VStack(spacing: width * 0.18) {
            ZStack {
                Circle()
                    .stroke(Palette.acc, lineWidth: 1.5)
                    .frame(width: buttonSize, height: buttonSize)
                    .scaleEffect(1 + 0.32 * halo)
                    .opacity(0.6 * (1 - halo))
                Circle().fill(Palette.acc.opacity(0.16)).frame(width: buttonSize, height: buttonSize)
                Circle().strokeBorder(Palette.acc.opacity(0.55), lineWidth: 1.5).frame(width: buttonSize, height: buttonSize)
                Image(systemName: "play.fill")
                    .font(.system(size: buttonSize * 0.36, weight: .semibold))
                    .foregroundStyle(Palette.acc)
                    .offset(x: buttonSize * 0.04)
            }
            Capsule()
                .fill(Palette.Remote.screenText.opacity(0.35))
                .frame(width: width * 0.42, height: max(2.5, width * 0.045))
        }
        .padding(.top, width * 0.2)
    }
}
