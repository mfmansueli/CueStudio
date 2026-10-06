//
//  UniverseShareSheet.swift
//  Cue Studio
//

import SwiftUI

/// 9.2 · Share your {year}: the 9:16 card, **Image | 6 s video**, **Show numbers** and **Show @handle**, and the two buttons: **Save to Photos** (glass)
/// and **Share…** (yellow; the system share sheet).
struct UniverseShareSheet: View {
    @State var viewModel: UniverseShareViewModel
    @Environment(ToastService.self) private var toast

    private static let previewWidth: CGFloat = 150

    var body: some View {
        VStack(spacing: 14) {
            Text("Share your \(String(viewModel.snapshot.year))").font(.headline)
            // The board's preview: the card at 150 pt wide.
            viewModel.card()
                .scaleEffect(Self.previewWidth / UniverseShareOptions.cardSize.width)
                .frame(width: Self.previewWidth, height: UniverseShareOptions.cardSize.height * Self.previewWidth / UniverseShareOptions.cardSize.width)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 16)
                .accessibilityLabel(Text("Preview of your universe card"))
                .accessibilityIdentifier("universeShare.preview")
            Picker("Format", selection: $viewModel.options.kind) {
                Text("Image").tag(UniverseShareOptions.Kind.image)
                Text("6 s video").tag(UniverseShareOptions.Kind.video)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("universeShare.kind")
            VStack(spacing: 0) {
                Toggle("Show numbers", isOn: $viewModel.options.showsNumbers)
                    .accessibilityIdentifier("universeShare.numbers")
                Divider().padding(.vertical, 10)
                Toggle("Show @handle", isOn: $viewModel.options.showsHandle)
                    .accessibilityIdentifier("universeShare.handle")
            }
            .tint(Palette.successText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            HStack(spacing: 12) {
                Button { Task { await viewModel.save() } } label: { Text("Save to Photos").frame(maxWidth: .infinity) }
                    .buttonStyle(.cueSecondary(.large))
                    .accessibilityIdentifier("universeShare.save")
                Button { Task { await viewModel.share() } } label: { Text("Share…").frame(maxWidth: .infinity) }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("universeShare.share")
            }
            .disabled(viewModel.isRendering)
            status
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 16)
        .fittedSheet()
        .sheet(item: $viewModel.sharedFile) { file in ActivityView(items: [file.url]).presentationDetents([.medium, .large]) }
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .saved { toast.show(String(localized: "Saved to Photos")) }
            if phase == .failed { toast.show(String(localized: "Couldn't save · Try again")) }
        }
    }

    @ViewBuilder
    private var status: some View {
        if case .rendering(let progress) = viewModel.phase {
            ProgressView(value: progress).tint(Palette.acc).accessibilityIdentifier("universeShare.progress")
        }
    }
}
