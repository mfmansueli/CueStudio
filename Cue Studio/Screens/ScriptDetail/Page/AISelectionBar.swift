//
//  AISelectionBar.swift
//  Cue Studio
//

import SwiftUI

/// The AI bar over a selection, made like the cues bar under it (`ScriptCuesBar`; owner, 02/11/2026): one full-width Liquid Glass bar,
/// 52 pt high, tinted night violet, with each way to rewrite as its own violet tag (✦ Rewrite · Shorter · Punchier · More me), whole on
/// one line and scrolling inside the bar (fading at its edges) when they don't all fit, then a divider and Cut (✂) fixed at the end, as
/// the cues bar's "+" is. While the model works it says "DRAFTING…" with Stop (✕) at the end (the page waits meanwhile); once the new
/// words are in the text it offers ✓ Keep · ↺ Undo · ✦ Try again. It doesn't exist without Apple Intelligence.
struct AISelectionBar: View {
    enum Phase: Equatable {
        case choosing
        case writing
        case replaced
    }

    let phase: Phase
    let onAction: (SelectionAction) -> Void
    let onKeep: () -> Void
    let onUndo: () -> Void
    let onRetry: () -> Void
    var onStop: () -> Void = {}

    /// The cues bar's own measures, so the two bars read as one family.
    private static let height: CGFloat = 52
    private static let tagHeight: CGFloat = 34
    /// How far the tags fade out before the bar's ends.
    private static let fade: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            switch phase {
            case .choosing:
                tags {
                    ForEach(SelectionAction.allCases.filter { $0 != .cut }) { action in
                        tag(Text(action.label), icon: action == .rewrite ? "sparkles" : nil, id: action.rawValue) { onAction(action) }
                    }
                }
                divider
                endButton("scissors", label: Text(SelectionAction.cut.label), id: SelectionAction.cut.rawValue, tint: Palette.ink) {
                    onAction(.cut)
                }
            case .writing:
                drafting
                Spacer(minLength: 0)
                divider
                endButton("xmark", label: Text("Stop"), id: "stop", tint: Palette.aiTextStrong, action: onStop)
            case .replaced:
                tags {
                    tag(Text("Keep"), icon: "checkmark", id: "keep", ink: Palette.successText, fill: Palette.Page.readyFill, action: onKeep)
                    tag(Text("Undo"), icon: "arrow.uturn.backward", id: "undo", action: onUndo)
                    tag(Text("Try again"), icon: "sparkles", id: "retry", action: onRetry)
                }
            }
        }
        .frame(height: Self.height)
        .glassEffect(.regular.tint(Palette.Page.selectionBar), in: Capsule())
        .padding(.horizontal, 10)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.selectionBar")
    }

    /// The tags, scrolling inside the bar when they don't all fit.
    private func tags(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) { content() }
                .padding(.horizontal, 10)
        }
        .scrollIndicators(.hidden)
        .mask(edgeFade)
    }

    private var drafting: some View {
        HStack(spacing: 8) {
            ProgressView().tint(Palette.aiText).scaleEffect(0.8)
            Text("Drafting…")
                .monoFont(size: 10.5, weight: .bold)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Palette.aiText)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("page.selection.writing")
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.separator)
            .frame(width: 1, height: 24)
            .accessibilityHidden(true)
    }

    /// Opaque in the middle, clear at both ends: a tag scrolling out fades before the divider instead of being cut by it.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: Self.fade)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: Self.fade)
        }
    }

    /// One way to rewrite (or to settle the new words): a violet tag, its name whole on one line.
    private func tag(
        _ title: Text, icon: String?, id: String, ink: Color = Palette.aiTextStrong, fill: Color = Palette.aiFill,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).cueFont(12, weight: .bold) }
                title
            }
            .cueFont(14, weight: .semibold)
            .foregroundStyle(ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 13)
            .frame(minHeight: Self.tagHeight)
            .background(fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("page.selection.\(id)")
    }

    /// The bar's last slot, fixed after the divider like the cues bar's "+": Cut, or Stop while the model works.
    private func endButton(_ symbol: String, label: Text, id: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.fixed(17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: Self.height, height: Self.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("page.selection.\(id)")
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        AISelectionBar(phase: .choosing, onAction: { _ in }, onKeep: {}, onUndo: {}, onRetry: {})
        AISelectionBar(phase: .writing, onAction: { _ in }, onKeep: {}, onUndo: {}, onRetry: {})
        AISelectionBar(phase: .replaced, onAction: { _ in }, onKeep: {}, onUndo: {}, onRetry: {})
    }
    .padding(.vertical)
    .background(Palette.bg)
    .environment(\.locale, Locale(identifier: "pt-BR"))
}
#endif
