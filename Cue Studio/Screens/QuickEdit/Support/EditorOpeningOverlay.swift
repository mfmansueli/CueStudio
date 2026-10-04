//
//  EditorOpeningOverlay.swift
//  Cue Studio
//

import SwiftUI

/// "Opening your edit": while the take is being read, the editor's layout shows as quiet blocks and a violet card says
/// what is happening, with a bar that moves until the take is ready. Nothing is claimed that isn't happening.
struct EditorOpeningOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text("OPENING YOUR EDIT")
                    .font(CueStudioFont.hud)
                    .tracking(1.5)
                    .foregroundStyle(Palette.ink2)
                    .padding(.top, 20)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.aiBorder, lineWidth: 0.5))
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .padding(.top, 18)
                    .padding(.horizontal, 60)
                    .overlay(alignment: .bottom) { card.padding(.horizontal, 28).offset(y: 24) }
                Spacer(minLength: 40)
                skeleton
                Text("Your take is read and put on the timeline in a moment.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkHint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 18)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Opening your edit"))
        .accessibilityIdentifier("edit.opening")
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("✦").foregroundStyle(Palette.aiText)
                Text("Getting your take ready")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.aiTextStrong)
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let phase = reduceMotion ? 0.5 : (context.date.timeIntervalSinceReferenceDate / 1.4).truncatingRemainder(dividingBy: 1)
                GeometryReader { proxy in
                    Capsule().fill(Color.white.opacity(0.12))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LinearGradient(colors: [Palette.aiText, Palette.acc], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * 0.35)
                                .offset(x: (proxy.size.width * 0.65) * phase)
                        }
                        .clipShape(Capsule())
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: shape)
        .background(Palette.surface.opacity(0.9), in: shape)
        .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface2).frame(width: 44, height: 56)
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface2).frame(height: 56)
            }
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surface).frame(width: 150, height: 26)
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surface).frame(width: 220, height: 26)
        }
        .padding(.horizontal, 16)
    }
}
