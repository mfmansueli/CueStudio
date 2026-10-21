//
//  RemoteHero.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The top of Settings › Remote (owner's choice, 21/10/2026: "two devices"): this iPhone as the teleprompter and the device that drives
/// it (`RemotePhone`), in three stages (`RemoteStage`; where they stand, `RemoteSceneLayout`).
/// - Apart: the two float out of step, and a dotted link drifts from the remote toward the teleprompter, broken in the middle.
/// - Pairing: the teleprompter glides to the middle and grows, its script fades into the code and its reading line sweeps it like a
///   scanner; rings leave it one after another, like a signal (the first two felt as the faintest ticks); the remote steps away.
/// - Linked: the remote comes back and the two lean in; the link draws itself from the remote to the teleprompter in green, a ✓ pops at
///   its peak with the connect haptic, a ring of light leaves the ✓, and light runs along the link, a command at a time. Let go, the link
///   pulls back into the remote, the ✓ shrinks away and the dots drift again.
/// The glow under the scene turns from the prompter's yellow to green as the link draws. Everything moves on one clock, so the link always
/// meets the devices where they are. Reduce Motion: the same places and colours, nothing moving, a stage arrives at once.
struct RemoteHero: View {
    let stage: RemoteStage
    /// What the pairing code stands for (`RemoteControlService.pairingURL`): drawn as a QR on the teleprompter while it waits.
    let pairingText: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var epoch = Date.now
    @State private var width: CGFloat = 358
    /// Where the devices stood when the stage last changed, and when.
    @State private var from: RemoteSceneLayout?
    @State private var changedAt = Date.distantPast
    @State private var linkedAt: Date?
    @State private var unlinkedAt: Date?
    @State private var pairingAt = Date.distantPast
    @State private var codeImage: UIImage?

    /// Seconds between two rings while pairing, and how long one takes to fade out.
    private static let ringGap: TimeInterval = 0.87
    private static let ringLife: TimeInterval = 2.6
    /// Seconds the link takes to draw itself, after the remote has started to come back.
    private static let drawDelay: TimeInterval = 0.15
    private static let drawDuration: TimeInterval = 0.6
    /// When the ✓ pops, after the stage turns linked: as the link, nearly drawn, reaches the teleprompter. The click, the ✓ and its
    /// ring of light all happen then.
    private static let popDelay: TimeInterval = 0.51
    /// Seconds for a command's light to run the length of the link.
    private static let pulseRun: TimeInterval = 1.6

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let now = context.date
            let scene = layout(at: now)
            let time = now.timeIntervalSince(epoch)
            ZStack {
                Canvas { canvas, size in
                    drawGlow(in: &canvas, size: size, now: now)
                    drawRings(in: &canvas, scene: scene, now: now)
                    drawLink(in: &canvas, scene: scene, now: now, time: time)
                }
                device(.prompter, scene.prompter, code: scene.code, time: time)
                device(.remote, scene.remote, code: 0, time: time)
                check(scene: scene, now: now)
            }
        }
        .frame(height: RemoteSceneLayout.sceneHeight)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: stage) { old, new in changeStage(from: old, to: new) }
        .task(id: pairingText) { codeImage = pairingText.flatMap(QRCodeView.makeImage(for:)) }
        .task(id: stage) { await playHaptics(for: stage) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier("remote.statusHero")
    }

    private var accessibilityLabel: String {
        switch stage {
        case .apart: String(localized: "No remote connected")
        case .pairing: String(localized: "Waiting for your other device…")
        case .linked: String(localized: "Remote connected")
        }
    }

    // MARK: - Where things are

    /// Where the devices stand now, on their way to this stage, floating.
    private func layout(at now: Date) -> RemoteSceneLayout {
        let target = RemoteSceneLayout.layout(for: stage, width: width)
        guard !reduceMotion else { return target }
        let progress = RemoteSceneLayout.settle(now.timeIntervalSince(changedAt))
        let moving = from.map { $0.interpolated(to: target, progress: progress) } ?? target
        return moving.floating(at: now.timeIntervalSince(epoch))
    }

    private func changeStage(from old: RemoteStage, to new: RemoteStage) {
        let now = Date.now
        let target = RemoteSceneLayout.layout(for: old, width: width)
        let progress = RemoteSceneLayout.settle(now.timeIntervalSince(changedAt))
        from = from.map { $0.interpolated(to: target, progress: progress) } ?? target
        changedAt = now
        if new == .linked { linkedAt = now }
        if old == .linked { unlinkedAt = now }
        if new == .pairing { pairingAt = now }
    }

    /// How much of the green link is drawn: from the remote out while it connects, back into it once let go.
    private func drawn(at now: Date) -> Double {
        if stage == .linked {
            guard let linkedAt, !reduceMotion else { return 1 }
            return RemoteSceneLayout.ease(now.timeIntervalSince(linkedAt) - Self.drawDelay, over: Self.drawDuration)
        }
        guard let unlinkedAt, !reduceMotion else { return 0 }
        return 1 - RemoteSceneLayout.ease(now.timeIntervalSince(unlinkedAt), over: 0.4)
    }

    /// How much the dotted link shows: once apart, coming in after the devices have started to move.
    private func dotted(at now: Date) -> Double {
        guard stage == .apart else { return 0 }
        guard !reduceMotion else { return 1 }
        return RemoteSceneLayout.ease(now.timeIntervalSince(changedAt) - 0.3, over: 0.5)
    }

    // MARK: - Drawing

    /// A round glow squashed into an ellipse, so it fades to nothing at every edge (a gradient filling an ellipse would stop at its rim).
    private func drawGlow(in canvas: inout GraphicsContext, size: CGSize, now: Date) {
        let live = drawn(at: now)
        let pairing = stage == .pairing ? 1.0 : 0
        let radius = size.width * 0.5
        let squash = 0.6
        for (color, amount) in [(Palette.Remote.glowIdle, (0.10 + 0.06 * pairing) * (1 - live)), (Palette.Remote.glowLive, 0.16 * live)] where amount > 0 {
            canvas.drawLayer { layer in
                layer.translateBy(x: size.width / 2, y: size.height * 0.52)
                layer.scaleBy(x: 1, y: squash)
                let disc = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
                layer.fill(
                    Path(ellipseIn: disc),
                    with: .radialGradient(Gradient(colors: [color.opacity(amount), color.opacity(0)]), center: .zero, startRadius: 0, endRadius: radius)
                )
            }
        }
    }

    /// The rings the teleprompter sends while it waits, one every `ringGap`, each easing out and fading.
    private func drawRings(in canvas: inout GraphicsContext, scene: RemoteSceneLayout, now: Date) {
        guard scene.code > 0.01, !reduceMotion else { return }
        // From just round the device to a little past it, inside the scene.
        let inner = scene.prompter.height * 0.36
        let elapsed = now.timeIntervalSince(pairingAt)
        for ring in 0..<3 {
            let since = elapsed - Double(ring) * Self.ringGap
            guard since >= 0 else { continue }
            let phase = since.truncatingRemainder(dividingBy: Self.ringLife) / Self.ringLife
            let radius = inner * (1 + 0.42 * RemoteSceneLayout.ease(phase, over: 1))
            let box = CGRect(x: scene.prompter.center.x - radius, y: scene.prompter.center.y - radius, width: radius * 2, height: radius * 2)
            canvas.stroke(Path(ellipseIn: box), with: .color(Palette.acc.opacity(0.5 * (1 - phase) * scene.code)), lineWidth: 1.5)
        }
    }

    private func drawLink(in canvas: inout GraphicsContext, scene: RemoteSceneLayout, now: Date, time: TimeInterval) {
        let (start, control1, control2, end) = scene.link
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        let dots = dotted(at: now) * scene.remote.opacity
        if dots > 0 {
            let style = StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 9], dashPhase: reduceMotion ? 0 : -time * 14)
            for piece in [path.trimmedPath(from: 0, to: 0.42), path.trimmedPath(from: 0.58, to: 1)] {
                canvas.stroke(piece, with: .color(Palette.Remote.linkIdle.opacity(dots)), style: style)
            }
        }
        let live = drawn(at: now)
        guard live > 0 else { return }
        let drawnPath = path.trimmedPath(from: 0, to: live)
        canvas.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            layer.stroke(drawnPath, with: .color(Palette.Remote.linkLive.opacity(0.5)), lineWidth: 5)
        }
        canvas.stroke(drawnPath, with: .color(Palette.Remote.linkLive), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        guard stage == .linked, !reduceMotion, let linkedAt else { return }
        drawFlash(in: &canvas, at: scene.linkPoint(at: 0.5), since: now.timeIntervalSince(linkedAt) - Self.popDelay)
        guard live >= 1 else { return }
        let sinceDrawn = now.timeIntervalSince(linkedAt) - Self.drawDelay - Self.drawDuration
        // Commands: three lights running from the remote to the teleprompter, a third of a run apart, brightest mid-way.
        for (index, radius) in [3.2, 2.4, 2.0].enumerated() {
            let run = sinceDrawn / Self.pulseRun - Double(index) / 3
            guard run >= 0 else { continue }
            let fraction = run.truncatingRemainder(dividingBy: 1)
            let point = scene.linkPoint(at: fraction)
            let strength = sin(.pi * fraction)
            let core = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            canvas.drawLayer { layer in
                layer.addFilter(.blur(radius: 3))
                layer.fill(Path(ellipseIn: core.insetBy(dx: -2, dy: -2)), with: .color(Palette.Remote.linkLive.opacity(0.8 * strength)))
            }
            canvas.fill(Path(ellipseIn: core), with: .color(Palette.Remote.pulse.opacity(strength)))
        }
    }

    /// The ring of light that leaves the ✓ as it pops.
    private func drawFlash(in canvas: inout GraphicsContext, at point: CGPoint, since: TimeInterval) {
        let life = 0.7
        guard since > 0, since < life else { return }
        let radius = 15 + 34 * RemoteSceneLayout.ease(since, over: life)
        let box = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        canvas.stroke(Path(ellipseIn: box), with: .color(Palette.Remote.linkLive.opacity(0.6 * (1 - since / life))), lineWidth: 2)
    }

    private func device(_ kind: RemotePhone.Kind, _ device: RemoteSceneLayout.Device, code: Double, time: TimeInterval) -> some View {
        RemotePhone(kind: kind, width: device.width, code: code, codeImage: codeImage, time: time, moves: !reduceMotion)
            .rotationEffect(.degrees(device.tilt))
            .opacity(device.opacity)
            .position(device.center)
    }

    /// The ✓ at the link's peak: pops once the link reaches it, shrinks away when the remote is let go.
    private func check(scene: RemoteSceneLayout, now: Date) -> some View {
        let scale: Double = {
            if stage == .linked {
                guard let linkedAt, !reduceMotion else { return 1 }
                return RemoteSceneLayout.pop(now.timeIntervalSince(linkedAt) - Self.popDelay)
            }
            guard let unlinkedAt, !reduceMotion else { return 0 }
            return 1 - RemoteSceneLayout.ease(now.timeIntervalSince(unlinkedAt), over: 0.25)
        }()
        return ZStack {
            Circle().fill(Palette.success)
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Palette.Remote.checkInk)
        }
        .frame(width: 30, height: 30)
        .shadow(color: Palette.success.opacity(0.5), radius: 8)
        .scaleEffect(max(0, scale))
        .opacity(scale > 0.01 ? 1 : 0)
        .position(scene.linkPoint(at: 0.5))
    }

    // MARK: - Haptics

    /// In time with the scene: the connect click as the ✓ pops; while pairing, a faint tick as each of the next two rings leaves (the
    /// first was felt with the tap on Connect). Only for a stage just reached, never for the one the page opened on.
    private func playHaptics(for stage: RemoteStage) async {
        switch stage {
        case .linked:
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : Self.popDelay))
            guard !Task.isCancelled, Date.now.timeIntervalSince(changedAt) < 2 else { return }
            HapticPatterns.playRemoteConnect()
        case .pairing:
            for _ in 0..<2 {
                try? await Task.sleep(for: .seconds(Self.ringGap))
                guard !Task.isCancelled, !reduceMotion, Date.now.timeIntervalSince(changedAt) < 3 else { return }
                HapticPatterns.playRemoteWave()
            }
        case .apart:
            break
        }
    }
}
