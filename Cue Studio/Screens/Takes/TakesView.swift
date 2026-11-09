//
//  TakesView.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// Every recording, one card or row per video (takes grouped by script), under the pipeline: how
/// many videos are to pick, in edit, ready and shared, and what to do next. A 9:16 grid by default,
/// a list on request, filtered by platform and by stage, in Today, Yesterday and Earlier. "Import video" brings a video from
/// Photos in to edit, shown as imported (not as a take).
struct TakesView: View {
    @State private var viewModel: TakesViewModel
    @AppStorage(DefaultsKey.takesLayout) private var layoutValue = TakeLayout.grid.rawValue

    /// Every service, for the lifted card (`peek`), which the system draws outside this screen's hierarchy.
    private let services: AppServices

    @Environment(TakeLibraryService.self) private var takes
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(MilestoneService.self) private var milestones
    @Environment(ScriptLibraryService.self) private var library
    @Environment(PresentationService.self) private var presentation
    @Environment(FirstVoyageService.self) private var voyage
    @Environment(\.scenePhase) private var scenePhase
    /// "Remind me…" from a video's menu: a reminder for its best take.
    @State private var reminding: TakeVideo?
    /// The video picked in "Import video".
    @State private var importing: PhotosPickerItem?
    /// The platform row, folded into the chosen chip or open (`FilterFan`).
    @State private var filterFan = FilterFanState()

    init(services: AppServices) {
        self.services = services
        _viewModel = State(initialValue: TakesViewModel(
            takes: services.takes, library: services.library, drafts: services.drafts,
            presentation: services.presentation, toast: services.toast, onboarding: services.onboarding, guidance: services.guidance
        ))
    }

    /// Nothing else has Takes: no sheet, camera or other tab.
    private var isQuiet: Bool {
        presentation.sheet == nil && presentation.prompter == nil && presentation.selectedTab == .takes
    }

    private var layout: Binding<TakeLayout> {
        Binding(get: { TakeLayout(rawValue: layoutValue) ?? .grid }, set: { layoutValue = $0.rawValue })
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if viewModel.isEmpty {
                emptyTakes
            } else if layout.wrappedValue == .grid {
                grid
            } else {
                list
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The first voyage's next step, 10 pt above the tab bar; the My Cue Voice question waits while it has one.
            VStack(spacing: 10) {
                VoyageFloatingTip(place: .takes, isQuiet: isQuiet && services.toast.message == nil)
                VoiceQuestionTipHost(place: .takes, isQuiet: isQuiet && voyage.floatingStep == nil)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .skyBackground()
        .navigationTitle("Takes")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            // A video from Photos, to edit without recording it here first.
            ToolbarItem(placement: .topBarLeading) {
                PhotosPicker(selection: $importing, matching: .videos, photoLibrary: .shared()) {
                    Label("Import video", systemImage: "square.and.arrow.down")
                }
                // In the bar's ink like the app's other bar buttons, not the yellow of an action (owner, 30/10/2026).
                .tint(Palette.ink)
                .disabled(viewModel.isImporting)
                .accessibilityIdentifier("takes.importVideo")
            }
            if !viewModel.isEmpty {
                // The segmented control has its own track: no glass capsule of the bar's around it.
                ToolbarItem(placement: .topBarTrailing) { TakesLayoutToggle(layout: layout) }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        .onChange(of: importing) { _, item in
            guard let item else { return }
            importing = nil
            Task { await viewModel.importVideo(item) }
        }
        .onAppear { viewModel.refresh(); takeRequest(); lightFirstStar() }
        .onChange(of: presentation.takesRequest) { _, _ in takeRequest() }
        // Back from the camera or a review, or on its tab again: the first star lights where the creator sees it.
        .onChange(of: isQuiet) { _, quiet in if quiet { lightFirstStar() } }
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
        .sheet(item: $reminding) { video in
            if let take = video.best {
                ReminderSheet(subject: .take(take.id), title: video.title) { ReminderFeedback.show($0, toast: services.toast) }
            }
        }
    }

    /// The first video's star, lit on its card once Takes is the screen in front: a soft tap, and VoiceOver hears it.
    private func lightFirstStar() {
        guard isQuiet, viewModel.lightFirstStar() else { return }
        Haptics.soft()
        AccessibilityNotification.Announcement(String(localized: "Your first video. Your first star.")).post()
    }

    /// The request "Your universe" left for Takes, taken once.
    private func takeRequest() {
        guard let request = presentation.takesRequest else { return }
        presentation.takesRequest = nil
        let videos = UniverseVideo.resolve(
            records: milestones.records, takes: takes.takes, scripts: library.scripts, fallbackDate: milestones.firstShareDate ?? .now
        )
        viewModel.apply(request, sharedVideos: videos)
    }

    /// The empty state (E): the mark, one line, one action and a way to a script.
    private var emptyTakes: some View {
        EmptyState(
            icon: .takes, title: "No takes yet", message: "Record a script. Every take lands here.", actionTitle: "Record",
            actionDot: Palette.record, action: { presentation.present(.startRecording) },
            linkTitle: "Pick a script ›", link: { presentation.selectedTab = .scripts },
            accessibilityPrefix: "takes.empty"
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - Header

    /// The pipeline, what to do next and the filters: above both layouts (6.2; the count of takes and videos above it is gone, owner 30/10/2026:
    /// it added nothing).
    private var header: some View {
        @Bindable var viewModel = viewModel
        let pipeline = viewModel.pipeline
        return VStack(alignment: .leading, spacing: 14) {
            TakePipelineCard(pipeline: pipeline, selected: viewModel.filter.stage, onSelect: { viewModel.toggle($0) })
            // UP NEXT and the first voyage's tip would say the same next step twice: the tip, while it is up, is the one.
            if let next = pipeline.next, voyage.floatingStep == nil {
                TakeUpNextCard(
                    next: next, onOpen: { viewModel.open(next.video) }, onAct: { viewModel.open(next.video, then: Self.action(for: next.stage)) }
                )
            }
            TakesFilterChips(
                scope: viewModel.scope, onClearScope: { viewModel.clearScope() },
                platform: $viewModel.filter.platform, fan: $filterFan, options: viewModel.platformOptions
            )
            .padding(.horizontal, -Metrics.gutter)
            .padding(.vertical, -6)
        }
    }

    /// The step a video is waiting at: picking its best take, finishing the edit, or sharing it.
    private static func action(for stage: TakeStage) -> ReviewLaunchAction {
        switch stage {
        case .pick: .pickBest
        case .edit: .edit
        case .ready, .shared: .share
        }
    }

    @ViewBuilder
    private var emptyStage: some View {
        let sections = viewModel.sections
        if sections.isEmpty {
            VStack(spacing: 10) {
                if let platform = viewModel.filter.platform {
                    // The platform is part of why it is empty: the stage's own words ("Nothing ready yet") would blame the stage alone.
                    Text("No videos for \(platform.label) here").cueFont(.title3, weight: .bold)
                    Text("Pick another stage or platform, or show every video.")
                        .cueFont(.body)
                        .foregroundStyle(Palette.ink2)
                } else if let stage = viewModel.filter.stage {
                    Text(stage.emptyTitle).cueFont(.title3, weight: .bold)
                    Text(stage.emptyDetail)
                        .cueFont(.body)
                        .foregroundStyle(Palette.ink2)
                } else {
                    Text("No takes here yet.")
                        .cueFont(.subheadline)
                        .foregroundStyle(Palette.ink2)
                }
                if viewModel.isNarrowed {
                    Button("Show every video") { viewModel.showEverything() }
                        .buttonStyle(.cueSecondary(.compact, expands: false))
                        .padding(.top, 6)
                        .accessibilityIdentifier("takes.showAll")
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 50)
            .accessibilityElement(children: .contain)
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
                    // One column at the accessibility text sizes: in two, a card's title held a word.
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(section.videos) { video in
                            Button { viewModel.open(video) } label: {
                                TakeVideoCard(video: video, showsFirstStar: video.id == viewModel.firstStarVideoID)
                            }
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
        .foldsFilterFan($filterFan)
    }

    private func dayTitle(_ day: TakeDay) -> some View {
        Text(day.label)
            .cueFont(.title3, weight: .bold)
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
                    ForEach(Array(section.videos.enumerated()), id: \.element.id) { index, video in
                        Button { viewModel.open(video) } label: {
                            TakeVideoRow(
                                video: video, whenLabel: video.latest.map(viewModel.whenLabel(for:)) ?? "",
                                showsFirstStar: video.id == viewModel.firstStarVideoID
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .cardRowSurface(Palette.surface, position: CardRowPosition(index: index, count: section.videos.count))
                        .contextMenu { actions(for: video) } preview: { peek(video) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { viewModel.videoToDelete = video } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Palette.dangerFill)
                            Button { viewModel.open(video, then: .share) } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(Palette.Takes.shareAction)
                        }
                        .accessibilityIdentifier("takes.video.\(video.id)")
                    }
                } header: {
                    Text(section.day.label)
                        .cueFont(.title3, weight: .bold)
                        .foregroundStyle(Palette.ink)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .foldsFilterFan($filterFan)
    }

    // MARK: - Peek

    /// Hold a video: Share, Edit, Retake, mark the best, Delete.
    @ViewBuilder
    private func actions(for video: TakeVideo) -> some View {
        Button { viewModel.open(video, then: .share) } label: { Label("Share", systemImage: "square.and.arrow.up") }
        Button { viewModel.open(video, then: .edit) } label: { Label("Edit", systemImage: "pencil") }
        // An imported video has no script or camera to go back to (the review hides Retake too).
        if video.best?.isImported != true {
            Button { viewModel.retake(video) } label: { Label("Retake", systemImage: "arrow.counterclockwise") }
        }
        Button { reminding = video } label: { Label("Remind me…", systemImage: "bell") }
        Button { viewModel.markBest(video) } label: {
            if video.best?.isBest == true {
                Label("Best take", systemImage: "star.fill")
            } else {
                Label("Mark as best", systemImage: "star")
            }
        }
        Button(role: .destructive) { viewModel.videoToDelete = video } label: { Label("Delete", systemImage: "trash") }
    }

    /// The lifted card. The system draws it outside this screen's hierarchy, without the services the app hands its screens, so it
    /// gets all of them here (its poster, `TakeThumbnail`, reads two); without them holding a video crashed.
    private func peek(_ video: TakeVideo) -> some View {
        TakeVideoCard(video: video)
            .frame(width: 220)
            .padding(10)
            .background(Palette.bg)
            .environment(services)
    }
}

#if DEBUG
#Preview {
    NavigationStack { TakesView(services: .preview) }
        .previewEnvironment()
}
#endif
