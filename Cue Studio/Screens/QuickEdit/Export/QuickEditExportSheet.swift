//
//  QuickEditExportSheet.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Export: what goes out (the take, its length, its format, captions and texts burned in), at
/// which resolution and frame rate, about how big, and the free exports left. Then the real
/// progress ("Exporting · keep Cue open"), and "Saved to Photos" with Done and Share.
struct QuickEditExportSheet: View {
    @State private var model: QuickEditExportModel
    let viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var thumbnail: UIImage?

    init(viewModel: QuickEditViewModel, services: AppServices) {
        self.viewModel = viewModel
        let store = services.store
        _model = State(initialValue: QuickEditExportModel(
            take: viewModel.take, videoURL: viewModel.videoURL, edit: { viewModel.edit },
            takes: services.takes, quota: services.quota, tier: { store.tier },
            exporter: services.exporter, photos: services.photos, editing: services.editing, ledger: services.ledger
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch model.phase {
            case .setup: setup
            case .exporting(let fraction): progress(fraction)
            case .done: done
            case .failed(let message): failed(message)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .presentationDetents([.height(460), .large])
        .presentationCornerRadius(Metrics.editorSheetRadius)
        .presentationBackground(Palette.surface)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(model.isExporting)
        .task {
            guard thumbnail == nil else { return }
            thumbnail = await thumbnails.thumbnail(for: viewModel.videoURL, maxPixelSize: 240)
        }
        .sheet(isPresented: Binding(get: { model.activity != nil }, set: { if !$0 { model.activity = nil } })) {
            if let share = model.activity {
                ActivityView(items: [share.url]) { model.activityFinished($0, for: share) }
                    .presentationDetents([.medium, .large])
            }
        }
        .onDisappear { model.leave() }
        .fullScreenCover(item: $model.paywall) { context in
            PaywallView(context: context) { Task { await model.continueAfterPurchase() } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.export")
    }

    // MARK: - Phases

    @ViewBuilder
    private var setup: some View {
        HStack {
            Text("Export").font(.system(.title3, weight: .bold)).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Palette.fill, in: Circle())
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("edit.export.close")
        }
        HStack(spacing: 14) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable().scaledToFill()
                } else {
                    Palette.surface2
                }
            }
            .frame(width: 54, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.title).font(.system(.callout, weight: .semibold).monospacedDigit())
                Text(model.summary).font(.system(.footnote)).foregroundStyle(Palette.ink2)
            }
        }
        PanelSegmented(
            label: String(localized: "Resolution"),
            options: VideoResolution.allCases.map { PanelOption($0, $0.label, isEnabled: model.canExport($0)) },
            selection: model.resolution, identifier: "edit.export.resolution"
        ) { model.resolution = $0 }
        PanelSegmented(
            label: String(localized: "Frame rate"),
            options: model.frameRates.map { PanelOption($0, String(localized: "\($0) fps"), isEnabled: model.canExport(frameRate: $0)) },
            selection: model.frameRate, identifier: "edit.export.frameRate"
        ) { model.frameRate = $0 }
        if let note = model.limitNote {
            PanelNote(text: note)
        }
        HStack {
            Text(String(localized: "Estimated size \(model.estimatedSize)"))
            Spacer(minLength: 8)
            if let left = model.exportsLeftLabel {
                Text(left)
            }
        }
        .font(.system(.footnote).monospacedDigit())
        .foregroundStyle(Palette.ink.opacity(0.7))
        Button { Task { await model.start() } } label: {
            Text("Export video")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(Palette.accInk)
                .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                .background(Palette.acc, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.export.start")
    }

    private func progress(_ fraction: Double) -> some View {
        VStack(spacing: 14) {
            Text(fraction.formatted(.percent.precision(.fractionLength(0)).locale(.interface)))
                .font(.system(.largeTitle, weight: .bold).monospacedDigit())
                .accessibilityIdentifier("edit.export.progress")
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.Slider.track)
                    Capsule().fill(Palette.acc).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 6)
            Text("Exporting · keep Cue open").font(.system(.subheadline)).foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var done: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.accInk)
                .frame(width: 56, height: 56)
                .background(Palette.acc, in: Circle())
            Text("Saved to Photos").font(.system(.title3, weight: .bold)).accessibilityIdentifier("edit.export.saved")
            Text("Your edits stay in this take.").font(.system(.subheadline)).foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Done").font(.system(.callout, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                    .background(Palette.fill, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit.export.done")
            Button {
                if case .done(let url) = model.phase { model.share(url) }
            } label: {
                Text("Share").font(.system(.callout, weight: .bold))
                    .foregroundStyle(Palette.accInk)
                    .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                    .background(Palette.acc, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit.export.share")
        }
    }

    @ViewBuilder
    private func failed(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 30)).foregroundStyle(Palette.warnText)
            Text("Couldn't export").font(.system(.title3, weight: .bold))
            Text(message).font(.system(.subheadline)).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        PanelButton(label: String(localized: "Try again"), isPrimary: true, identifier: "edit.export.retry", action: model.retry)
    }
}
