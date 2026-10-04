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

    @State private var showsEditProfile = false
    @State private var showsManageSubscriptions = false
    @State private var showsVoicePreview = false
    @State private var paywall: PaywallContext?
    @State private var trialDays: Int?
    /// The My Cue Voice questions opened from the card (all that is missing, or one row to edit).
    @State private var voiceSetup: ProfileVoiceSetup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Button { showsEditProfile = true } label: {
                    ProfileIdentityRow(profile: profile.profile, isPro: store.tier.isPro)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.creatorCard")

                ProfileBlockLabel(text: "YOUR UNIVERSE")
                NavigationLink { YourUniverseView() } label: { UniverseProfileCard() }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile.universeLink")

                ProfileBlockLabel(text: "MY CUE VOICE")
                MyCueVoiceCard(setup: $voiceSetup, onPreview: { showsVoicePreview = true })

                ProfileBlockLabel(text: "PLAN")
                ProfilePlanCard(onUpgrade: { paywall = .profile }, onManage: { showsManageSubscriptions = true })
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .skyBackground()
        .navigationTitle("Profile")
        .toolbarTitleDisplayMode(.inlineLarge)
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
