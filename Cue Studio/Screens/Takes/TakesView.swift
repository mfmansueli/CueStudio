//
//  TakesView.swift
//  Cue Studio
//

import SwiftUI

/// Every recording, one row per video (takes grouped by script), filtered by platform and by
/// best / not shared / edited, in Today, Yesterday and Earlier.
struct TakesView: View {
    @State private var viewModel: TakesViewModel

    @Environment(TakeLibraryService.self) private var takes
    @Environment(PresentationService.self) private var presentation

    init(services: AppServices) {
        _viewModel = State(initialValue: TakesViewModel(takes: services.takes, library: services.library, toast: services.toast))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView {
                    Label("No takes yet", systemImage: "film.stack")
                } description: {
                    Text("Your recordings show up here, one row per video.")
                } actions: {
                    Button("Record a take") { presentation.present(.startRecording) }
                        .buttonStyle(.cuePrimary(.regular, expands: false))
                        .accessibilityIdentifier("takes.recordButton")
                }
            } else {
                library
            }
        }
        .background(Palette.bg)
        .navigationTitle("Takes")
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationSubtitle(viewModel.summary)
        .confirmationDialog(
            viewModel.videoToDelete?.title ?? "",
            isPresented: Binding(get: { viewModel.videoToDelete != nil }, set: { if !$0 { viewModel.videoToDelete = nil } }),
            titleVisibility: .visible,
            presenting: viewModel.videoToDelete
        ) { video in
            Button(video.takes.count == 1 ? String(localized: "Delete take") : String(localized: "Delete \(video.takes.count) takes"), role: .destructive) {
                viewModel.deleteConfirmed()
            }
        } message: { _ in
            Text("The videos are removed from Cue. Copies you saved to Photos stay there.")
        }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                filters
                let sections = viewModel.sections
                if sections.isEmpty {
                    Text("No takes here yet.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                }
                ForEach(sections) { section in
                    Text(section.day.label)
                        .font(.title3.bold())
                        .padding(EdgeInsets(top: 22, leading: Metrics.textGutter, bottom: 8, trailing: Metrics.textGutter))
                        .accessibilityAddTraits(.isHeader)
                    GroupedCard(dividerInset: 98) {
                        ForEach(section.videos) { video in
                            row(video)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var filters: some View {
        @Bindable var viewModel = viewModel
        return VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(viewModel.platformOptions, id: \.self) { platform in
                        Button { viewModel.filter.platform = platform } label: {
                            FilterChip(
                                label: platform?.label ?? String(localized: "All"),
                                isSelected: viewModel.filter.platform == platform,
                                dotColor: platform?.tint
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(viewModel.filter.platform == platform ? .isSelected : [])
                        .accessibilityIdentifier("takes.platform.\(platform?.rawValue ?? "all")")
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(TakeLibraryView.allCases) { view in
                        let isOn = viewModel.filter.view == view
                        Button { viewModel.filter.view = view } label: {
                            Text(view.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(isOn ? Palette.acc : Palette.ink.opacity(0.75))
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(isOn ? Palette.acc.opacity(0.1) : .clear, in: Capsule())
                                .overlay(Capsule().strokeBorder(isOn ? Palette.acc.opacity(0.5) : Palette.ink.opacity(0.16), lineWidth: 1))
                                .frame(minHeight: Metrics.hitTarget)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        .accessibilityIdentifier("takes.view.\(view.rawValue)")
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 6)
    }

    private func row(_ video: TakeVideo) -> some View {
        Button {
            if let best = video.best { presentation.openReview(of: best) }
        } label: {
            TakeVideoRow(video: video, whenLabel: video.latest.map(viewModel.whenLabel(for:)) ?? "")
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(video.takes.count == 1 ? "Delete take" : "Delete takes", systemImage: "trash", role: .destructive) {
                viewModel.videoToDelete = video
            }
        }
        .accessibilityIdentifier("takes.video.\(video.id)")
    }
}

#if DEBUG
#Preview {
    NavigationStack { TakesView(services: .preview) }
        .previewEnvironment()
}
#endif
