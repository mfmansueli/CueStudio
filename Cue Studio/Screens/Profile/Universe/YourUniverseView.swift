//
//  YourUniverseView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// 9.2 · Your universe, one per year: the live year grows with every video shared, the years before it are sealed. The core in the middle, the
/// platforms as planets that grow with the videos, a dot for every video, the themes, the next milestone (or the year's card), "Your {year} in review"
/// and one yellow button, under the system's large title. The year selector (‹ year ›) is in the bar; the map has no swipe of its own, so the
/// back swipe works from anywhere. Built from what is on this iPhone.
struct YourUniverseView: View {
    @Environment(MilestoneService.self) private var milestones
    @Environment(TakeLibraryService.self) private var takes
    @Environment(ScriptLibraryService.self) private var library
    @Environment(TopicTaggingService.self) private var tagging
    @Environment(PresentationService.self) private var presentation
    @Environment(PersonalizationService.self) private var personalization
    @Environment(CreatorProfileService.self) private var profile
    @Environment(PhotoLibraryManager.self) private var photos
    @Environment(ToastService.self) private var toast

    @State private var chosenYear: Int?
    @State private var showsCore = false
    @State private var story: UniverseYearRequest?
    @State private var shareRequest: UniverseYearRequest?
    /// "Share my {year}" from the story: its sheet opens once the story has gone.
    @State private var pendingShare: UniverseYearRequest?
    @State private var previousCounts: [Platform: Int] = [:]
    @Environment(NotificationService.self) private var notifications
    /// Opened from "Your year in review is ready": the story opens as the screen appears (once).
    private let opensYearInReview: Bool
    @State private var openedYearInReview = false

    init(opensYearInReview: Bool = false) {
        self.opensYearInReview = opensYearInReview
    }

    private var videos: [UniverseVideo] {
        UniverseVideo.resolve(records: milestones.records, takes: takes.takes, scripts: library.scripts, fallbackDate: milestones.firstShareDate ?? .now)
    }

    private var content: UniverseContent {
        UniverseContent(videos: videos, topics: tagging.topics, selectedYear: chosenYear)
    }

    var body: some View {
        let content = content
        let snapshot = content.snapshot
        GeometryReader { screen in
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header(content)
                if let badge = content.sealedBadge { UniverseSealedBadge(text: badge) }
                map(content, snapshot: snapshot)
                if snapshot.total > 0 { UniverseLegend(snapshot: snapshot) { openTakes(theme: $0, year: snapshot.year) } }
                // With nothing to draw the cards go to the bottom, just over the button, as on the board.
                Spacer(minLength: 12)
                card(content)
                UniverseReviewRowView(row: content.review) { openReview(content) }
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
            .frame(minHeight: screen.size.height)
        }
        }
        .skyBackground(wash: BgWash.yourUniverse)
        .accessibilityIdentifier("universe.screen")
        .safeAreaInset(edge: .bottom) { actionButton(content).padding(.horizontal, Metrics.gutter).padding(.bottom, 8) }
        // The system's bar, large title and back: going back follows the finger the way every pushed page does (a page of its own with the bar
        // hidden slid its title over Profile's, 30/10/2026).
        .navigationTitle("Your universe")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if content.showsSelector {
                ToolbarItem(placement: .topBarTrailing) {
                    UniverseYearSelector(years: content.years, selected: content.selectedYear) { year in
                        withAnimation(.easeInOut(duration: 0.25)) { chosenYear = year }
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .task(id: content.selectedYear) { await notePlanets(content.snapshot) }
        .onAppear {
            // Visiting is what "Your universe" is for: its introduction stops.
            notifications.recordUse(.yourUniverse)
            guard opensYearInReview, !openedYearInReview else { return }
            openedYearInReview = true
            openReview(content)
        }
        .sheet(isPresented: $showsCore) { UniverseCoreSheet(snapshot: snapshot) }
        .sheet(item: $shareRequest) { request in
            UniverseShareSheet(viewModel: UniverseShareViewModel(
                snapshot: UniverseSnapshot(videos: videos, year: request.year, topics: tagging.topics),
                handle: profile.profile.handle, coreColor: personalization.coreColor, photos: photos
            ))
        }
        // The story is a full-screen cover (it hides the tab bar too) that fades in over 0.3 s; "Share my {year}" opens its sheet once it has gone.
        .fullScreenCover(item: $story, onDismiss: {
            guard let pending = pendingShare else { return }
            pendingShare = nil
            shareRequest = pending
        }, content: { request in
            YearInReviewView(
                stats: YearStats(videos: videos, year: request.year, topics: tagging.topics),
                isSealed: UniverseYears.isSealed(request.year),
                onShare: { pendingShare = UniverseYearRequest(year: request.year) },
                onClose: {
                    var instant = Transaction()
                    instant.disablesAnimations = true
                    withTransaction(instant) { story = nil }
                }
            )
        })
    }

    // MARK: - Pieces

    private func map(_ content: UniverseContent, snapshot: UniverseSnapshot) -> some View {
        UniverseMap(
            snapshot: snapshot, coreColor: personalization.coreColor, isSealed: content.isSealed, ghost: content.ghost, caption: content.caption,
            previousCounts: previousCounts,
            onCore: { showsCore = true },
            onSeeInTakes: { openTakes(platform: $0, year: snapshot.year) },
            onDot: { openTake($0) },
            playsOpening: true
        )
        .id(content.selectedYear)
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    /// The line under the system's large title ("1 VIDEO SHARED IN 2026"); the year selector is in the bar.
    private func header(_ content: UniverseContent) -> some View {
        Text(content.headline)
            .monoFont(size: 11, weight: .semibold)
            .interfaceTracking(1.2)
            .foregroundStyle(Palette.accText)
            .padding(.horizontal, 2)
            .accessibilityIdentifier("universe.headline")
    }

    @ViewBuilder
    private func card(_ content: UniverseContent) -> some View {
        switch content.state {
        case .newAccount:
            UniverseInfoCard(
                eyebrow: String(localized: "FIRST STAR · 0 / 1"), title: String(localized: "Share your first video"),
                detail: String(localized: "It lights the first star of your universe"), progress: 0, icon: .aurora, identifier: "universe.firstStar"
            )
        case .newYear:
            UniverseInfoCard(
                eyebrow: String(localized: "FIRST STAR OF \(String(content.selectedYear)) · 0 / 1"), title: String(localized: "Share your first video"),
                detail: String(localized: "It starts this year’s universe"), progress: 0,
                // The year looks back; the icons are the life's milestones, so the picture is the next one still to win (never Aurora, already theirs).
                icon: milestones.nextMilestone.flatMap(AppIconChoice.init(milestone:)), identifier: "universe.firstStar"
            )
        case .sealed:
            if let card = content.yearCard {
                UniverseInfoCard(eyebrow: card.eyebrow, title: card.title, detail: card.detail, progress: 1, icon: .deepSpace, identifier: "universe.yearCard")
            }
        case .live:
            if let next = milestones.nextMilestone, let icon = AppIconChoice(milestone: next) {
                UniverseInfoCard(
                    // Counted over the creator's life, like the icon it opens (`MilestoneService`).
                    eyebrow: String(localized: "NEXT MILESTONE · \(milestones.shares) / \(next)"),
                    title: String(localized: "Share \(next - milestones.shares) more videos"),
                    detail: String(localized: "Unlocks the \(icon.title) app icon"), progress: milestones.progress, icon: icon,
                    identifier: "universe.nextMilestone"
                )
            }
        }
    }

    private func actionButton(_ content: UniverseContent) -> some View {
        Button { perform(content) } label: {
            Label(content.actionTitle, systemImage: content.action == .record ? "video.fill" : "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.cuePrimary(.large))
        .shineSweep(interval: 4.8)
        .accessibilityIdentifier(content.action == .record ? "universe.record" : "universe.share")
    }

    // MARK: - Actions

    private func perform(_ content: UniverseContent) {
        switch content.action {
        case .record:
            presentation.present(.startRecording)
        case .share(let year):
            chosenYear = year
            shareRequest = UniverseYearRequest(year: year)
        }
    }

    private func openReview(_ content: UniverseContent) {
        let row = content.review
        guard !row.isLocked else {
            toast.show(String(localized: "Share 3 videos to unlock it"), kind: .problem)
            return
        }
        if content.reviewSwitchesYear { chosenYear = row.year }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { story = UniverseYearRequest(year: row.year) }
    }

    private func openTakes(platform: Platform, year: Int) {
        presentation.openTakes(TakesRequest(platform: platform, topic: nil, year: year))
    }

    private func openTakes(theme: OnboardingTopic, year: Int) {
        presentation.openTakes(TakesRequest(platform: nil, topic: theme.id, year: year))
    }

    private func openTake(_ id: UUID) {
        guard let take = takes.takes.first(where: { $0.id == id }) else { return }
        presentation.openReview(of: take)
    }

    /// The planets grow from what they had when this was last open; a detail they win gets a soft tap.
    private func notePlanets(_ snapshot: UniverseSnapshot) async {
        let seen = milestones.seenPlanetCounts(year: snapshot.year)
        let now = Dictionary(uniqueKeysWithValues: snapshot.platforms.map { ($0.platform, $0.count) })
        let grew = now.contains { (platform, count) in (seen[platform] ?? count) < count }
        previousCounts = grew ? seen : [:]
        if grew, personalization.haptics, now.contains(where: { PlanetSize.detail(videos: seen[$0.key] ?? $0.value) < PlanetSize.detail(videos: $0.value) }) {
            try? await Task.sleep(for: .milliseconds(450))
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        milestones.markPlanetsSeen(now, year: snapshot.year)
    }
}

#if DEBUG
#Preview {
    NavigationStack { YourUniverseView() }
        .previewEnvironment()
}
#endif
