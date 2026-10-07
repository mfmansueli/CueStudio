//
//  PickBestTakeView.swift
//  Cue Studio
//

import SwiftUI

/// "Pick your best take": the video's takes side by side, with the one Cue suggests in the middle and why. The side
/// takes slide in, a violet line scans the middle one, the "✦ Best take" badge lights with a wave and the reasons
/// come up one by one. Cue only suggests: "Use take 2" is the creator's choice.
struct PickBestTakeView: View {
    let proposal: BestTakeProposal
    let onUse: (Take) -> Void
    let onRecordAgain: () -> Void
    let onOpen: (Take) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: UUID?
    @State private var slidIn = false
    @State private var scan = 0.0
    @State private var isScanning = true
    @State private var revealed = false
    @State private var chipsShown = 0

    private var chosen: Take { proposal.takes.first { $0.id == selection } ?? proposal.best }
    private var isBestChosen: Bool { chosen.id == proposal.best.id }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(proxy.size.width * 0.6, max(150, (proxy.size.height - 500) * 9 / 16))
            ZStack {
                Palette.bg.ignoresSafeArea()
                RadialGradient(colors: [Palette.aiGlow, .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.8)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    Text("Pick your best take")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 14)
                    carousel(cardWidth: cardWidth, screenWidth: proxy.size.width)
                        .padding(.top, 14)
                    dots.padding(.top, 8)
                    reasons
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    Spacer(minLength: 12)
                    buttons.padding(.horizontal, 16).padding(.bottom, 8)
                }
            }
        }
        .task { await play() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pick.sheet")
    }

    // MARK: - Parts

    private var topBar: some View {
        ZStack {
            HStack {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.cueIcon(.glass, diameter: 40))
                    .accessibilityLabel(Text("Close"))
                    .accessibilityIdentifier("pick.closeButton")
                Spacer()
            }
            Text("TO PICK · \(proposal.takes.count) TAKES")
                .font(CueStudioFont.hud)
                .tracking(1.5)
                .foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func carousel(cardWidth: CGFloat, screenWidth: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 14) {
                ForEach(proposal.takes) { take in
                    card(take, width: cardWidth)
                        .id(take.id)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content.scaleEffect(phase.isIdentity ? 1 : 0.86).opacity(phase.isIdentity ? 1 : 0.55)
                        }
                        .offset(x: slidIn || reduceMotion ? 0 : (take.id == proposal.best.id ? 0 : sideOffset(of: take)))
                        .opacity(slidIn || reduceMotion || take.id == proposal.best.id ? 1 : 0)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, (screenWidth - cardWidth) / 2, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selection, anchor: .center)
        .frame(height: cardWidth * 16 / 9 + 24)
    }

    private func sideOffset(of take: Take) -> CGFloat {
        let before = (proposal.takes.firstIndex { $0.id == take.id } ?? 0) < (proposal.takes.firstIndex { $0.id == proposal.best.id } ?? 0)
        return before ? -60 : 60
    }

    private func card(_ take: Take, width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        let isChosen = take.id == chosen.id
        let isBest = take.id == proposal.best.id
        return ZStack {
            TakeThumbnail(take: take)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            Button { onOpen(take) } label: {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Watch \(take.label)"))
            .accessibilityIdentifier("pick.watch.\(take.number)")
            VStack {
                HStack {
                    if isBest { badge }
                    Spacer()
                }
                Spacer()
                HStack {
                    Text(take.label.uppercased())
                    Spacer()
                    Text(DurationText.clock(take.duration))
                }
                .font(CueStudioFont.hud)
                .foregroundStyle(.white)
            }
            .padding(14)
            if isBest, isChosen, isScanning { scanLine }
        }
        .frame(width: width, height: width * 16 / 9)
        .clipShape(shape)
        .overlay(shape.strokeBorder(isChosen ? Palette.aiText : Palette.glassBorder, lineWidth: isChosen ? 2 : 0.5))
        .cardDepth(shape, edge: nil)
        .shadow(color: isChosen ? Palette.aiText.opacity(0.45) : .clear, radius: 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(take.label), \(DurationText.clock(take.duration))"))
        .accessibilityIdentifier("pick.take.\(take.number)")
    }

    /// "✦ Best take", lit with a wave when Cue has looked at the takes.
    private var badge: some View {
        HStack(spacing: 6) {
            Text("✦").foregroundStyle(Palette.aiText)
            Text("Best take").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.aiTextStrong)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Palette.bg.opacity(0.85), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5))
        .background { IgniteEffect(trigger: revealed ? 1 : 0, color: Palette.aiText, diameter: 10).offset(x: -26) }
        .scaleEffect(revealed || reduceMotion ? 1 : 0.4, anchor: .leading)
        .opacity(revealed || reduceMotion ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: revealed)
        .accessibilityIdentifier("pick.bestBadge")
    }

    /// A violet line that scans the middle take while Cue looks.
    private var scanLine: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Palette.aiText, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .shadow(color: Palette.aiText, radius: 8)
                .offset(y: proxy.size.height * scan)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(proposal.takes) { take in
                Capsule()
                    .fill(take.id == chosen.id ? Palette.aiText : Color.white.opacity(0.3))
                    .frame(width: take.id == chosen.id ? 26 : 8, height: 8)
            }
        }
        .animation(.smooth(duration: 0.25), value: selection)
        .accessibilityHidden(true)
    }

    // MARK: - Why

    private var reasons: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 12) {
            Text(isBestChosen ? "✦ WHY CUE PICKED \(chosen.label.uppercased())" : "✦ \(chosen.label.uppercased()) · CUE PICKED \(proposal.best.label.uppercased())")
                .font(CueStudioFont.hud)
                .tracking(1.2)
                .foregroundStyle(Palette.aiText)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                    chipView(chip)
                        .scaleEffect(shown(index) ? 1 : 0.7)
                        .opacity(shown(index) ? 1 : 0)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.65), value: chipsShown)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pick.reasons")
    }

    private struct Chip {
        let text: String
        let isGood: Bool
    }

    private func shown(_ index: Int) -> Bool { !isBestChosen || reduceMotion || index < chipsShown }

    private var chips: [Chip] {
        guard isBestChosen else { return otherTakeChips }
        var result = proposal.reasons.map { reason -> Chip in
            switch reason {
            case .fitsPlatform(let duration):
                Chip(text: String(localized: "✓ Fits \(proposal.platformLabel) · \(DurationText.clock(duration))"), isGood: true)
            case .readWholeScript: Chip(text: String(localized: "Read the whole script"), isGood: false)
            case .closestToScript: Chip(text: String(localized: "Closest to your script’s length"), isGood: false)
            }
        }
        if result.isEmpty { result = [Chip(text: String(localized: "Your best fit so far"), isGood: false)] }
        return result
    }

    /// What can be said of a take Cue didn't pick: how its length sits.
    private var otherTakeChips: [Chip] {
        let fit = LengthFit(seconds: chosen.duration, ideal: proposal.ideal)
        return [Chip(text: fit.label, isGood: fit.verdict == .fits), Chip(text: DurationText.clock(chosen.duration), isGood: false)]
    }

    private func chipView(_ chip: Chip) -> some View {
        Text(chip.text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(chip.isGood ? Palette.successText : Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(chip.isGood ? Palette.success.opacity(0.16) : Palette.surface2, in: Capsule())
    }

    // MARK: - Actions

    private var buttons: some View {
        HStack(spacing: 12) {
            Button(action: onRecordAgain) {
                HStack(spacing: 10) {
                    Circle().fill(Palette.record).frame(width: 12, height: 12)
                    Text("Record again")
                }
            }
            .buttonStyle(.cueSecondary(.large))
            .accessibilityIdentifier("pick.recordAgain")
            Button { onUse(chosen) } label: { Text("Use \(chosen.label)") }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("pick.use")
        }
    }

    // MARK: - Motion

    /// Side takes slide in, the line scans twice, then the badge lights and the reasons come one by one.
    private func play() async {
        selection = proposal.best.id
        guard !reduceMotion else {
            slidIn = true; isScanning = false; revealed = true; chipsShown = chips.count
            return
        }
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)) { slidIn = true }
        withAnimation(.easeInOut(duration: 0.7).repeatCount(2, autoreverses: false)) { scan = 1 }
        try? await Task.sleep(for: .milliseconds(1400))
        guard !Task.isCancelled else { return }
        isScanning = false
        revealed = true
        Haptics.soft()
        for index in 1...max(1, chips.count) {
            chipsShown = index
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
        }
    }
}
