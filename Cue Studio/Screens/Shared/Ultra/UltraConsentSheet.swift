//
//  UltraConsentSheet.swift
//  Cue Studio
//

import SwiftUI

/// Asked before Ultra sends anything, as an invitation (owner, 31/10/2026: short, inviting, the free scripts first; 02/11/2026: richer, so the
/// creator wants to try it): Ultra AI's ✦ igniting in its galaxy (`UltraConsentHero`), "Meet Ultra AI" with a light that crosses it once, the
/// free scripts it may write, three glass rows on what it does that come in one after the other as their symbols light, and one line that
/// says the request goes to Anthropic and where to turn it off (Settings › Privacy & AI data has the rest), over a button that shines. The
/// page sits in the middle of the sheet, scrolling only when it doesn't fit. Allowing it is separate from the Apple Intelligence switch, and
/// saying no changes nothing else in Cue.
struct UltraConsentSheet: View {
    /// Allowing it writes the script at once (Find inspiration's idea), and the button says so; elsewhere it only picks Ultra AI.
    var writesNow = false
    /// The permission is given by the caller (`UltraConsentService.grant`), which then goes on.
    let onAllow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UltraScriptService.self) private var ultra
    /// The page has come in (the title's light, the rows, the button's shine follow it).
    @State private var opened = false
    @State private var pageHeight: CGFloat = 0

    /// When the title's light crosses it and when the first row comes in, after the ✦ ignites (`UltraConsentHero.ignition`).
    private static let titleLight = 0.85
    private static let rowsFrom = 1.0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    UltraConsentHero()
                    header
                    benefits
                }
                .padding(EdgeInsets(top: 12, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
                .frame(minHeight: pageHeight)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
            footer
        }
        .onAppear { opened = true }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ultra.consent")
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Meet Ultra AI")
                .cueFont(.title, weight: .bold)
                .foregroundStyle(Palette.ink)
                .overlay { titleLight }
                .accessibilityAddTraits(.isHeader)
            // The scripts it may write: the free ones to try it, or this month's with Cue Pro.
            if let allowance = ultra.allowance?.allowance {
                Text(verbatim: UltraAllowanceLabels.consent(allowance))
                    .cueFont(.title3, weight: .semibold)
                    .foregroundStyle(Palette.aiText)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityIdentifier("ultra.consent.allowance")
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A light that crosses the title once, after the ✦ ignites: a band of the star's cream, kept to the letters.
    private var titleLight: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [Palette.Universe.starCream.opacity(0), Palette.Universe.starCream.opacity(0.95), Palette.Universe.starCream.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: proxy.size.width * 0.35)
            .offset(x: opened && !reduceMotion ? proxy.size.width * 1.1 : -proxy.size.width * 0.45)
            .animation(.easeInOut(duration: 0.9).delay(Self.titleLight), value: opened)
        }
        .mask { Text("Meet Ultra AI").cueFont(.title, weight: .bold) }
        .opacity(reduceMotion ? 0 : 1)
        .allowsHitTesting(false)
    }

    private var benefits: some View {
        VStack(spacing: 10) {
            benefit("Goes further with every idea", systemImage: "sparkles", order: 0)
            benefit("Checks its claims as it writes", systemImage: "checkmark.seal", order: 1)
            benefit("Polished in your voice", systemImage: "waveform", order: 2)
        }
        .frame(maxWidth: .infinity)
    }

    /// A glass row: the symbol in a violet disc, lit (bigger, glowing) as the row comes in, and the line; the rows come in one after the
    /// other out of a blur.
    private func benefit(_ title: LocalizedStringKey, systemImage: String, order: Int) -> some View {
        let shown = opened || reduceMotion
        let delay = Self.rowsFrom + 0.12 * Double(order)
        return HStack(spacing: 14) {
            Image(systemName: systemImage)
                .cueFont(.body, weight: .semibold)
                .foregroundStyle(Palette.aiTextStrong)
                .frame(width: 38, height: 38)
                .background { Circle().fill(Palette.aiFill) }
                .overlay { Circle().strokeBorder(Palette.aiBorder, lineWidth: 0.75) }
                .shadow(color: Palette.aiText.opacity(shown ? 0.45 : 0), radius: 8)
                .scaleEffect(shown ? 1 : 0.6)
                .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.58).delay(delay + 0.1), value: opened)
                .accessibilityHidden(true)
            Text(title)
                .cueFont(.body, weight: .medium)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.fill) }
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.75) }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 12)
        .blur(radius: shown ? 0 : 4)
        .animation(reduceMotion ? nil : .smooth(duration: 0.5).delay(delay), value: opened)
    }

    /// What goes, in one line, over the two buttons.
    private var footer: some View {
        VStack(spacing: 12) {
            Text("Your idea, your choices and your My Cue Voice preferences go to Anthropic, which writes it. Turn it off any time in Settings.")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ultra.consent.disclosure")
            Button {
                onAllow()
                dismiss()
            } label: { Text(allowTitle) }
                .buttonStyle(.cuePrimary(.large))
                .shineSweep(interval: 5)
                .accessibilityIdentifier("ultra.consent.allow")
            Button { dismiss() } label: { Text("Not now") }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("ultra.consent.decline")
        }
        .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
    }

    /// The free scripts lead: "Try it free" while the first ones are still there.
    private var allowTitle: LocalizedStringKey {
        let free = (ultra.allowance?.allowance).map { $0.membership != .paid && $0.freeLeft > 0 } ?? false
        switch (free, writesNow) {
        case (true, true): return "Write it free with Ultra AI"
        case (true, false): return "Try it free"
        case (false, true): return "Allow and write with Ultra AI"
        case (false, false): return "Allow Ultra AI"
        }
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        UltraConsentSheet(onAllow: {})
    }
    .previewEnvironment()
}
#endif
