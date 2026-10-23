//
//  VoyageTipCard.swift
//  Cue Studio
//

import SwiftUI

/// A first voyage tip: "★ 4 OF 6" (which opens the list of steps), what to do and why in a line, at most two buttons and ✕. Above the
/// dock or the tab bar (`VoyageFloatingTip`), or in the place its step happens, never over what it talks about. The voyage decides
/// when it shows (one at a time: the next step's).
struct VoyageTipCard: View {
    /// The step the eyebrow counts: the one the tip is about, or the one ahead (the first draft's tip).
    let step: VoyageStep
    let symbol: String
    let title: String
    let message: String
    var primary: (title: String, action: () -> Void)?
    var secondary: (title: String, action: () -> Void)?
    /// The tip's own name for UI tests ("voyage.tip.3", "voyage.tip.draft").
    var identifier: String?
    let onClose: () -> Void

    @State private var showsSteps = false

    private static let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.aiText)
                    .frame(width: 36, height: 36)
                    .background(Palette.aiFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    eyebrow
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, -10)
                .padding(.trailing, -10)
                .accessibilityLabel(Text("Close tip"))
                .accessibilityIdentifier("voyage.tip.close")
            }
            if primary != nil || secondary != nil {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    if let secondary {
                        Button(secondary.title, action: secondary.action)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink2)
                            .frame(minHeight: Metrics.hitTarget)
                            .padding(.horizontal, 8)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("voyage.tip.secondary")
                    }
                    if let primary {
                        Button(primary.title, action: primary.action)
                            .buttonStyle(.cueSecondary(.compact, expands: false))
                            .accessibilityIdentifier("voyage.tip.primary")
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: primary == nil && secondary == nil ? 14 : 8, trailing: 14))
        .background(Palette.surface, in: Self.shape)
        .overlay(Self.shape.fill(Palette.aiFill).allowsHitTesting(false))
        .overlay(Self.shape.strokeBorder(Palette.aiBorder, lineWidth: 1).allowsHitTesting(false))
        .sheet(isPresented: $showsSteps) { VoyageStepsSheet() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier ?? "voyage.tip.\(step.number)")
    }

    /// "★ 4 OF 6": where the creator is, and the way to every step.
    private var eyebrow: some View {
        Button { showsSteps = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.acc)
                Text("\(step.number) OF \(VoyageProgress.stepCount)")
                    .monoFont(size: 10.5, weight: .semibold)
                    .interfaceTracking(1.2)
                    .foregroundStyle(Palette.aiText)
            }
            .frame(minHeight: 24)
            // 44 pt to touch, without pushing the words down.
            .padding(.vertical, 10)
            .padding(.trailing, 16)
            .contentShape(Rectangle())
            .padding(.vertical, -10)
            .padding(.trailing, -16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Step \(step.number) of \(VoyageProgress.stepCount)"))
        .accessibilityHint(Text("Shows every step"))
        .accessibilityIdentifier("voyage.tip.steps")
    }
}
