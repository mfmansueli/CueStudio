//
//  TakesView.swift
//  Cue Studio
//

import SwiftUI

/// Every recording, one card or row per video (takes grouped by script), under the pipeline: how
/// many videos are to pick, in edit, ready and shared, and what to do next. A 9:16 grid by default,
/// a list on request, filtered by platform and by stage, in Today, Yesterday and Earlier.
struct TakesView: View {
    @State private var viewModel: TakesViewModel
    @AppStorage(DefaultsKey.takesLayout) private var layoutValue = TakeLayout.grid.rawValue

    @Environment(TakeLibraryService.self) private var takes
    @Environment(PresentationService.self) private var presentation
    @Environment(\.scenePhase) private var scenePhase

    init(services: AppServices) {
        _viewModel = State(initialValue: TakesViewModel(
            takes: services.takes, library: services.library, drafts: services.drafts,
            presentation: services.presentation, toast: services.toast
        ))
    }

    private var layout: Binding<TakeLayout> {
        Binding(get: { TakeLayout(rawValue: layoutValue) ?? .grid }, set: { layoutValue = $0.rawValue })
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if viewModel.isEmpty {
                // The empty state (E): the mark, one line, one action and a way to a script.
                EmptyState(
                    icon: .takes, title: "No takes yet", message: "Record a script. Every take lands here.", actionTitle: "Record",
                    actionDot: Palette.record, action: { presentation.present(.startRecording) },
                    linkTitle: "Pick a script ›", link: { presentation.selectedTab = .scripts },
                    accessibilityPrefix: "takes.empty"
                )
                .frame(maxHeight: .infinity)
            } else if layout.wrappedValue == .grid {
                grid
            } else {
                list
            }
        }
        .skyBackground()
        .navigationTitle("Takes")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            if !viewModel.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { TakesLayoutToggle(layout: layout) }
                ToolbarItem(placement: .topBarTrailing) {
                    TakesPlatformMenu(platform: $viewModel.filter.platform, options: viewModel.platformOptions)
                }
            }
        }
        .onAppear { viewModel.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refresh() }
        }
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

    // MARK: - Header

    /// The count in yellow mono, the pipeline and what to do next: above both layouts.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HUDLine(values: viewModel.summaryValues, separator: " / ")
                .padding(.horizontal, 4)
            TakePipelineCard(
                pipeline: viewModel.pipeline, selected: viewModel.filter.stage,
                onSelect: { viewModel.toggle($0) },
                onNext: { viewModel.open($0.video) }
            )
            VoiceNudgeSlot()
        }
    }

    @ViewBuilder
    private var emptyStage: some View {
        let sections = viewModel.sections
        if sections.isEmpty {
            VStack(spacing: 10) {
                if let stage = viewModel.filter.stage {
                    Text(stage.emptyTitle).font(.title3.bold())
                    Text(stage.emptyDetail)
                        .font(.body)
                        .foregroundStyle(Palette.ink2)
                } else {
                    Text("No takes here yet.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 50)
            .accessibilityIdentifier("takes.emptyStage")
        }
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.horizontal, Metrics.gutter).padding(.top, 4)
                emptyStage
                ForEach(viewModel.sections) { section in
                    dayTitle(section.day)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 14) {
                        ForEach(section.videos) { video in
                            Button { viewModel.open(video) } label: { TakeVideoCard(video: video) }
                                .buttonStyle(.plain)
                                .contextMenu { actions(for: video) } preview: { peek(video) }
                                .accessibilityIdentifier("takes.video.\(video.id)")
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func dayTitle(_ day: TakeDay) -> some View {
        Text(day.label)
            .font(.title3.bold())
            .padding(EdgeInsets(top: 22, leading: Metrics.textGutter, bottom: 8, trailing: Metrics.textGutter))
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if viewModel.sections.isEmpty {
                emptyStage
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.videos) { video in
                        Button { viewModel.open(video) } label: {
                            TakeVideoRow(video: video, whenLabel: video.latest.map(viewModel.whenLabel(for:)) ?? "")
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Palette.surface)
                        .contextMenu { actions(for: video) } preview: { peek(video) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { viewModel.videoToDelete = video } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { viewModel.open(video, then: .share) } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(Palette.acc)
                        }
                        .accessibilityIdentifier("takes.video.\(video.id)")
                    }
                } header: {
                    Text(section.day.label)
                        .font(.title3.bold())
                        .foregroundStyle(Palette.ink)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Peek

    /// Hold a video: Share, Edit, Retake, mark the best, Delete.
    @ViewBuilder
    private func actions(for video: TakeVideo) -> some View {
        Button { viewModel.open(video, then: .share) } label: { Label("Share", systemImage: "square.and.arrow.up") }
        Button { viewModel.open(video, then: .edit) } label: { Label("Edit", systemImage: "pencil") }
        Button { viewModel.retake(video) } label: { Label("Retake", systemImage: "arrow.counterclockwise") }
        Button { viewModel.markBest(video) } label: {
            if video.best?.isBest == true {
                Label("Best take", systemImage: "star.fill")
            } else {
                Label("Mark as best", systemImage: "star")
            }
        }
        Button(role: .destructive) { viewModel.videoToDelete = video } label: { Label("Delete", systemImage: "trash") }
    }

    private func peek(_ video: TakeVideo) -> some View {
        TakeVideoCard(video: video)
            .frame(width: 220)
            .padding(10)
            .background(Palette.bg)
            .environment(takes)
    }
}

#if DEBUG
#Preview {
    NavigationStack { TakesView(services: .preview) }
        .previewEnvironment()
}
#endif
