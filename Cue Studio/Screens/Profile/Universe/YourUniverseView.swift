//
//  YourUniverseView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// 9.2 · Your universe, one per year: the live year grows with every video shared, the years before it are sealed. The core in the middle, the
/// platforms as planets that grow with the videos, a dot for every video, the themes, the next milestone (or the year's card), "Your {year} in review"
/// and one yellow button. The year selector is in the toolbar; a swipe on the map changes year too. Built from what is on this iPhone.
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
        .toolbar(.hidden, for: .navigationBar)
        .background { InteractivePopEnabler() }
        .task(id: content.selectedYear) { await notePlanets(content.snapshot) }
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
            onDot: { openTake($0) }
        )
        .id(content.selectedYear)
        .frame(maxWidth: .infinity)
        .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { value in swipe(value.translation, content) })
        .transition(.opacity)
    }

    /// The large title, the year selector on its right (once something was shared), and the line under them.
    private func header(_ content: UniverseContent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text("Your universe")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    // One line, as the board's: the system font is a little wider than the board's, so it eases down to fit beside the selector.
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if content.showsSelector {
                    UniverseYearSelector(years: content.years, selected: content.selectedYear) { year in
                        withAnimation(.easeInOut(duration: 0.25)) { chosenYear = year }
                    }
                }
            }
            Text(content.headline)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Palette.accText)
                .padding(.horizontal, 2)
                .accessibilityIdentifier("universe.headline")
        }
        .padding(.top, -6)
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
                detail: String(localized: "It starts this year’s universe"), progress: 0, icon: .aurora, identifier: "universe.firstStar"
            )
        case .sealed:
            if let card = content.yearCard {
                UniverseInfoCard(eyebrow: card.eyebrow, title: card.title, detail: card.detail, progress: 1, icon: .deepSpace, identifier: "universe.yearCard")
            }
        case .live:
            if let next = milestones.nextMilestone, let icon = AppIconChoice(milestone: next) {
                UniverseInfoCard(
                    eyebrow: String(localized: "NEXT MILESTONE · \(milestones.yearShares) / \(next)"),
                    title: String(localized: "Share \(next - milestones.yearShares) more videos"),
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
            toast.show(String(localized: "Share 3 videos to unlock it"))
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

    /// A swipe on the map goes to the year after or before.
    private func swipe(_ translation: CGSize, _ content: UniverseContent) {
        guard abs(translation.width) > abs(translation.height) * 1.5, let index = content.years.firstIndex(of: content.selectedYear) else { return }
        let target = translation.width < 0 ? index + 1 : index - 1
        guard content.years.indices.contains(target) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { chosenYear = content.years[target] }
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
