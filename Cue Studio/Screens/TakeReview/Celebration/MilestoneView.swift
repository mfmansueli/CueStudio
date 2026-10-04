//
//  MilestoneView.swift
//  Cue Studio
//

import SwiftUI

/// A milestone in the creator's universe (1, 10, 25 or 50 videos shared) opens an app icon. Light converges on a
/// point, the point flares with slow rays, and the screen offers the icon for the Home Screen.
struct MilestoneView: View {
    let milestone: Int
    let icon: AppIconChoice
    let since: Date?
    /// Whether the icon is free for this creator (Aurora) or comes with Pro.
    let isAvailable: Bool
    let onUse: () -> Void
    let onKeep: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var converge = 0.0
    @State private var flare = 0
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 0) {
            Text(milestone == 1 ? String(localized: "MILESTONE · FIRST VIDEO SHARED") : String(localized: "MILESTONE · \(milestone) VIDEOS SHARED"))
                .font(CueStudioFont.hud)
                .tracking(1.5)
                .foregroundStyle(Palette.accText)
                .padding(.top, 36)
            burst
                .frame(height: 340)
            Text("A new icon is yours.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed || reduceMotion ? 0 : 14)
            Text(message)
                .font(.system(size: 17))
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .opacity(revealed ? 1 : 0)
            homeScreenRow
                .padding(.top, 22)
                .opacity(revealed ? 1 : 0)
            Spacer(minLength: 12)
            VStack(spacing: 6) {
                Button(action: onUse) { Text(isAvailable ? String(localized: "Use \(icon.title)") : String(localized: "Get \(icon.title) with Pro")) }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("milestone.use")
                Button(action: onKeep) {
                    Text("Keep my current icon")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("milestone.keep")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .opacity(revealed ? 1 : 0)
        }
        .skyBackground()
        .task { await play() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("milestone.sheet")
    }

    private var message: String {
        if milestone == 1 { return String(localized: "Your first video is out in the world. \(icon.title) can live on your Home Screen.") }
        let day = since.map { $0.formatted(.dateTime.month(.wide).locale(.interface)) } ?? ""
        return String(localized: "\(milestone) videos carried out into the world since \(day). \(icon.title) can live on your Home Screen.")
    }

    // MARK: - Parts

    /// Specks of light fall in on a point; it flares and slow rays turn around it.
    private var burst: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.aiText.opacity(0.55), Palette.aiText.opacity(0)], center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 300, height: 300)
                    .opacity(0.4 + 0.6 * converge)
                ForEach(0..<16, id: \.self) { ray in
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top))
                        .frame(width: 3, height: 130 * (0.55 + 0.45 * converge))
                        .offset(y: -65 * (0.55 + 0.45 * converge))
                        .rotationEffect(.degrees(Double(ray) * 22.5 + time * 4))
                        .opacity(converge)
                }
                ForEach(0..<8, id: \.self) { speck in
                    let angle = Double(speck) / 8 * 2 * .pi + 0.4
                    Circle()
                        .fill(speck.isMultiple(of: 3) ? Palette.acc : Color.white)
                        .frame(width: 5, height: 5)
                        .offset(x: cos(angle) * 140 * (1 - converge), y: sin(angle) * 140 * (1 - converge))
                        .opacity(1 - converge * 0.9)
                }
                IgniteEffect(trigger: flare, color: .white, diameter: 18)
            }
        }
        .accessibilityHidden(true)
    }

    private var homeScreenRow: some View {
        VStack(spacing: 10) {
            Text("ON YOUR HOME SCREEN")
                .font(CueStudioFont.hud)
                .tracking(1.2)
                .foregroundStyle(Palette.inkHint)
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                    Group {
                        if index == 1, let name = icon.previewName {
                            Image(name).resizable().scaledToFill()
                        } else {
                            Palette.surface3
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(index == 1 ? Palette.acc : .clear, lineWidth: 2.5))
                }
            }
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Motion

    private func play() async {
        guard !reduceMotion else { converge = 1; revealed = true; return }
        withAnimation(.easeIn(duration: 1.3)) { converge = 1 }
        try? await Task.sleep(for: .milliseconds(1300))
        guard !Task.isCancelled else { return }
        flare += 1
        Haptics.success()
        withAnimation(.easeOut(duration: 0.5)) { revealed = true }
    }
}
