//
//  YourUniverseView.swift
//  Cue Studio
//

import SwiftUI

/// "Your universe": the topics as worlds and every shared video as a star, the platforms they travelled to, the next
/// milestone, and an image of it all to share. Built from what is on this iPhone.
struct YourUniverseView: View {
    @Environment(MilestoneService.self) private var milestones
    @Environment(TakeLibraryService.self) private var takes
    @Environment(ScriptLibraryService.self) private var library
    @Environment(TopicTaggingService.self) private var tagging
    @Environment(PresentationService.self) private var presentation
    @State private var shareImage: Image?
    @State private var yearImage: Image?

    private var snapshot: UniverseSnapshot {
        UniverseSnapshot(
            sharedIDs: milestones.sharedTakeIDs, takes: takes.takes, scripts: library.scripts, topics: tagging.topics,
            firstShare: milestones.firstShareDate
        )
    }

    var body: some View {
        let snapshot = snapshot
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(headline(snapshot))
                    .font(CueStudioFont.hud)
                    .tracking(1.2)
                    .foregroundStyle(Palette.accText)
                    .padding(.horizontal, 4)
                UniverseMap(snapshot: snapshot)
                    .frame(height: snapshot.total == 0 ? 190 : 400)
                if snapshot.total == 0 {
                    emptyState
                }
                legend(snapshot)
                nextMilestone
                Button { presentation.selectedTab = .scripts } label: { scriptsRow }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("universe.scriptsRow")
                shareButtons(snapshot)
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .skyBackground()
        .navigationTitle("Your universe")
        .toolbarTitleDisplayMode(.inlineLarge)
        .task(id: snapshot.total) { renderImages(snapshot) }
        .accessibilityIdentifier("universe.screen")
    }

    // MARK: - Pieces

    private func headline(_ snapshot: UniverseSnapshot) -> String {
        guard snapshot.total > 0 else { return String(localized: "NO VIDEOS SHARED YET") }
        let month = snapshot.firstShare.map { $0.formatted(.dateTime.month(.wide).locale(.interface)).uppercased() } ?? ""
        return String(localized: "\(snapshot.total) VIDEOS SHARED · SINCE \(month)")
    }

    /// E-9.2: nothing shared yet.
    private var emptyState: some View {
        EmptyState(
            icon: .star, title: "Your first star is one video away", message: "Share a video and it lights up here.",
            actionTitle: "Go to Takes", action: { presentation.selectedTab = .takes },
            accessibilityPrefix: "universe.empty"
        )
    }

    private func legend(_ snapshot: UniverseSnapshot) -> some View {
        FlowLayout(spacing: 16, lineSpacing: 8) {
            ForEach(Array(snapshot.topics.enumerated()), id: \.offset) { index, entry in
                HStack(spacing: 6) {
                    Circle().fill(OnboardingTopic.color(at: index)).frame(width: 10, height: 10)
                    Text(entry.topic.label).foregroundStyle(Palette.ink)
                    Text("\(entry.count)").foregroundStyle(Palette.ink3)
                }
                .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var nextMilestone: some View {
        if let next = milestones.nextMilestone, let icon = AppIconChoice(milestone: next) {
            let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
            HStack(spacing: 14) {
                if let name = icon.previewName {
                    Image(name).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEXT MILESTONE · \(milestones.shares) / \(next)")
                        .font(CueStudioFont.hud).tracking(1).foregroundStyle(Palette.accText)
                    Text("Share \(next - milestones.shares) more videos").font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text("Unlocks the \(icon.title) app icon").font(.subheadline).foregroundStyle(Palette.ink2)
                    ProgressView(value: milestones.progress).tint(Palette.acc)
                }
            }
            .padding(16)
            .background(Palette.surface, in: shape)
            .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("universe.nextMilestone")
        }
    }

    private var scriptsRow: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        return HStack(spacing: 14) {
            CueIconView(.scripts, size: 24).foregroundStyle(Palette.ink)
            Text("Scripts").font(.system(size: 19)).foregroundStyle(Palette.ink)
            Spacer()
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
        }
        .padding(18)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
    }

    @ViewBuilder
    private func shareButtons(_ snapshot: UniverseSnapshot) -> some View {
        if snapshot.total > 0, let shareImage {
            ShareLink(item: shareImage, preview: SharePreview(String(localized: "My universe"), image: shareImage)) {
                Label("Share my universe", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.cuePrimary(.large))
            .accessibilityIdentifier("universe.share")
            if let yearImage {
                ShareLink(item: yearImage, preview: SharePreview(String(localized: "My year in Cue"), image: yearImage)) {
                    Label("My year in Cue", systemImage: "sparkles")
                }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("universe.year")
            }
        }
    }

    @MainActor
    private func renderImages(_ snapshot: UniverseSnapshot) {
        guard snapshot.total > 0 else { return }
        let card = UniverseShareCard(snapshot: snapshot, mode: .universe)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        shareImage = renderer.uiImage.map(Image.init(uiImage:))
        let year = ImageRenderer(content: UniverseShareCard(snapshot: snapshot, mode: .year))
        year.scale = 3
        yearImage = year.uiImage.map(Image.init(uiImage:))
    }
}
