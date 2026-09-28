//
//  ShareToSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Share to": the platforms (the one the take was made for ringed in yellow), Save video and More,
/// then Burn in captions and Quality. On the free plan, how many free exports are left.
struct ShareToSheet: View {
    @Bindable var viewModel: TakeReviewViewModel
    let take: Take

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 16) {
                ForEach(ShareDestination.allCases) { destination in
                    destinationTile(destination)
                }
                actionTile(String(localized: "Save video"), systemImage: "arrow.down.to.line", identifier: "share.save") {
                    Task { await viewModel.save() }
                }
                actionTile(String(localized: "More"), systemImage: "ellipsis", identifier: "share.more") {
                    Task { await viewModel.share(to: nil) }
                }
            }
            if let platform = take.platform {
                Text("Created for \(platform.destinationName) — framed and safe-zoned for it")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
            options.padding(.top, 14)
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .disabled(viewModel.runningAction != nil)
        .fittedSheet()
    }

    private var header: some View {
        HStack(spacing: 12) {
            TakeThumbnail(take: take)
                .frame(width: 40, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("Share to")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(Palette.acc)
                Text(take.scriptTitle).font(.headline).lineLimit(1)
                Text(viewModel.shareMeta)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.ink2)
            }
            .buttonStyle(.cueIcon(.surface, diameter: 32))
            .accessibilityLabel(Text("Close"))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 18)
    }

    private func destinationTile(_ destination: ShareDestination) -> some View {
        let isRecommended = take.platform == destination.platform
        let isRunning = viewModel.runningAction == .share(destination)
        let shape = RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
        return Button {
            Task { await viewModel.share(to: destination) }
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    shape.fill(destination.platform.tint)
                    if isRunning {
                        ProgressView().tint(.white)
                    } else {
                        Text(destination.glyph)
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)
                .overlay {
                    if isRecommended {
                        shape.inset(by: -4).strokeBorder(Palette.acc, lineWidth: 2)
                    }
                }
                Text(destination.platform.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isRecommended ? Palette.acc : Palette.ink)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isRecommended ? "\(destination.platform.destinationName), recommended" : destination.platform.destinationName))
        .accessibilityIdentifier("share.\(destination.rawValue)")
    }

    private func actionTile(_ title: String, systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 56, height: 56)
                    .background(Palette.surface3, in: RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var options: some View {
        GroupedCard(background: Palette.surface2, radius: 22) {
            Toggle("Burn in captions", isOn: $viewModel.burnsInCaptions)
                .tint(Palette.success)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .accessibilityIdentifier("share.captionsToggle")
            HStack {
                Text("Quality")
                Spacer()
                Picker("Quality", selection: Binding(get: { viewModel.quality }, set: { viewModel.setQuality($0) })) {
                    ForEach(ExportQuality.allCases) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .accessibilityIdentifier("share.quality")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            if let notice = viewModel.exportNotice {
                HStack {
                    Text(notice).foregroundStyle(viewModel.exportsExhausted ? Palette.warn : Palette.ink2)
                    Spacer()
                    Button("Go Pro") { viewModel.paywall = .export }
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.acc)
                }
                .font(.footnote)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
            }
        }
    }
}
