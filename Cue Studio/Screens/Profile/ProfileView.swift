//
//  ProfileView.swift
//  Cue Studio
//

import StoreKit
import SwiftUI

/// 9.1 · Profile, four blocks on the night sky: who this is, "Your universe", "My Cue Voice" and the plan. Everything else the
/// old Profile held lives one tap away: name, handle, sign in and defaults in the profile sheet (tap the first block), the
/// fine-tuning of the voice under My Cue Voice (Edit voice), the plans in the paywall (tap the plan).
struct ProfileView: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(StoreManager.self) private var store
    @Environment(MilestoneService.self) private var milestones
    @Environment(TakeLibraryService.self) private var takes

    @State private var showsEditProfile = false
    @State private var showsManageSubscriptions = false
    @State private var showsVoicePreview = false
    @State private var paywall: PaywallContext?
    @State private var trialDays: Int?
    /// The My Cue Voice questions opened from the card (all that is missing, or one row to edit).
    @State private var voiceSetup: ProfileVoiceSetup?
    /// Where the identity row is (in the screen's own space), and whether its menu is open.
    @State private var identityFrame: CGRect = .zero
    @State private var showsMenu = false

    nonisolated private static let space = "profileScreen"

    private var universeSummary: ProfileUniverseSummary {
        let videos = UniverseVideo.resolve(records: milestones.records, takes: takes.takes, scripts: [], fallbackDate: milestones.firstShareDate ?? .now)
        let year = UniverseYears.current()
        let thisYear = videos.filter { $0.isIn(year: year) }.count
        let lastYear = UniverseYears.reviewYear(selected: year, videos: videos)
        return ProfileUniverseSummary(
            total: videos.count, sharedThisYear: thisYear, year: year, lastYear: lastYear,
            lastYearCount: videos.filter { $0.isIn(year: lastYear) }.count,
            topics: profile.profile.niches.count + profile.profile.customTopics.count,
            toNextMilestone: milestones.nextMilestone.map { $0 - milestones.yearShares }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileIdentityRow(profile: profile.profile, onEdit: { showsEditProfile = true }, onMenu: { showsMenu = true })
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { identityFrame = $0 }
                    .opacity(showsMenu ? 0 : 1)
                    .accessibilityIdentifier("profile.creatorCard")

                ProfileBlockLabel(text: "YOUR UNIVERSE")
                NavigationLink { YourUniverseView() } label: { ProfileUniverseRow(summary: universeSummary) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile.universeLink")
                Text(universeSummary.footer)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.ink2)
                    .padding(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 12))
                    .accessibilityIdentifier("profile.universeFooter")

                ProfileBlockLabel(text: "MY CUE VOICE")
                MyCueVoiceCard(setup: $voiceSetup, onPreview: { showsVoicePreview = true })

                ProfileBlockLabel(text: "PLAN")
                ProfilePlanCard(onUpgrade: { paywall = .profile }, onManage: { showsManageSubscriptions = true })
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .skyBackground()
        .coordinateSpace(.named(Self.space))
        .overlay {
            if showsMenu {
                ProfileContextMenu(profile: profile.profile, frame: identityFrame, onEdit: { showsEditProfile = true }, onClose: { showsMenu = false })
                    .transition(.opacity)
            }
        }
        .navigationTitle("Profile")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showsEditProfile = true }
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("profile.editButton")
            }
        }
        .task {
            await store.loadProducts()
            trialDays = await store.freeTrialDays(for: .annual)
        }
        .sheet(isPresented: $showsEditProfile) { EditProfileSheet() }
        .sheet(isPresented: $showsVoicePreview) { VoicePreviewSheet() }
        .sheet(item: $voiceSetup) { setup in
            VoiceSetupSheet(mode: setup.mode, profile: profile.profile, startAt: setup.startAt)
        }
        .fullScreenCover(item: $paywall) { PaywallView(context: $0) }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
    }
}

#if DEBUG
#Preview {
    NavigationStack { ProfileView() }
        .previewEnvironment()
}
#endif
