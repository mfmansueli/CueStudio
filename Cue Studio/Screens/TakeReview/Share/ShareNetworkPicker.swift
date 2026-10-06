//
//  ShareNetworkPicker.swift
//  Cue Studio
//

import SwiftUI

/// 8.1 · Share to universe: the thumbnail and title, "✓ CLEAN FILE FOR EVERY NETWORK · NO WATERMARKS", the networks with a check each, **Also save to
/// Photos**, and **Share to {n} networks** with what it costs under it. Below, what the export is made with (captions and quality), as before.
struct ShareNetworkPicker: View {
    @Bindable var flow: ShareFlow
    @Bindable var review: TakeReviewViewModel
    let take: Take

    @State private var showsOptions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Share to universe").font(.headline).frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        Button { showsOptions = true } label: { Image(systemName: "slider.horizontal.3") }
                            .buttonStyle(.cueIcon(.glass, diameter: 36))
                            .offset(y: -2)
                            .accessibilityLabel(Text("Export options"))
                            .accessibilityIdentifier("shareFlow.options")
                    }
                header
                GroupedCard(background: Palette.surface2, radius: 22) {
                    ForEach(Array(ShareNetworkLine.networks.enumerated()), id: \.element) { index, network in
                        if index > 0 { Divider().padding(.leading, 56) }
                        ShareNetworkRow(
                            network: network, line: line(for: network), isPicked: flow.isPicked(network),
                            isFromScript: take.platform == network.platform
                        ) { flow.toggle(network) }
                    }
                }
                GroupedCard(background: Palette.surface2, radius: 22) {
                    Toggle("Also save to Photos", isOn: $flow.alsoSavesToPhotos)
                        .tint(Palette.success)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .accessibilityIdentifier("shareFlow.saveToPhotos")
                }
                Button { Task { await flow.start() } } label: {
                    HStack(spacing: 8) {
                        if flow.isStarting { ProgressView().tint(Palette.accInk) }
                        Text(flow.startTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.cuePrimary(.large))
                .shineSweep(interval: 4.8)
                .disabled(!flow.canStart)
                .accessibilityIdentifier("shareFlow.start")
                if let cost = flow.costLine {
                    Text(cost.text)
                        .font(.footnote)
                        .foregroundStyle(cost.isWarning ? Palette.warnText : Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("shareFlow.cost")
                }
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 20, trailing: Metrics.gutter))
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsOptions) { ShareExportOptions(review: review).presentationDetents([.medium]).presentationBackground(Palette.sheetNight) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            TakeThumbnail(take: take)
                .frame(width: 40, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(take.scriptTitle).font(.system(size: 19, weight: .semibold)).lineLimit(2)
                Text("✓ CLEAN FILE FOR EVERY NETWORK · NO WATERMARKS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(0.6).foregroundStyle(Palette.successText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    /// "9:16 · 0:52 FITS", or how far off it is.
    private func line(for network: ShareDestination) -> String {
        let seconds = take.edit?.editedDuration ?? take.duration
        return ShareNetworkLine.text(
            for: network, aspect: take.outputAspect.label, isVertical: take.outputAspect == .portrait, seconds: seconds,
            ideal: review.idealRange(for: network.platform)
        )
    }
}
