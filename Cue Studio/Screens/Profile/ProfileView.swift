//
//  ProfileView.swift
//  Cue Studio
//

import StoreKit
import SwiftUI

/// Account, plan, Creator DNA and settings.
struct ProfileView: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast

    @State private var showsEditProfile = false
    @State private var showsPrivacy = false
    @State private var showsManageSubscriptions = false
    @State private var paywall: PaywallContext?
    @State private var isAddingPhrase = false
    @State private var newPhrase = ""
    @State private var trialDays: Int?

    var body: some View {
        @Bindable var profile = profile
        List {
            Section {
                Button { showsEditProfile = true } label: {
                    CreatorCard(profile: profile.profile, isPro: store.tier.isPro)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.creatorCard")
            }
            Section {
                PlanSection(
                    trialDays: trialDays,
                    onUpgrade: { paywall = .profile },
                    onManage: { showsManageSubscriptions = true }
                )
            }
            .listRowBackground(Rectangle().fill(store.tier.isPro ? AnyShapeStyle(proBackground) : AnyShapeStyle(Palette.surface)))
            Section {
                CreatorDNASection(onAddPhrase: {
                    newPhrase = ""
                    isAddingPhrase = true
                })
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Creator DNA")
                        .font(.title3.bold())
                        .foregroundStyle(Palette.ink)
                    Text("Cue's AI uses this to write scripts that sound like you. One profile for every platform.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                }
                .textCase(nil)
                .padding(.bottom, 4)
            }
            Section("Settings") {
                Picker("Default destination", selection: $profile.profile.defaultPlatform) {
                    ForEach(Platform.allCases) { Text($0.destinationName).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Palette.ink2)
                Toggle("Monetization goals", isOn: $profile.profile.monetizationGoals)
                    .tint(Palette.success)
                Button { showsPrivacy = true } label: {
                    HStack {
                        Text("Privacy & AI data").foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.ink3)
                    }
                }
                Button("Restore purchases") {
                    Task {
                        let restored = await store.restore()
                        toast.show(restored ? String(localized: "Purchases restored") : String(localized: "No purchases to restore"))
                    }
                }
                .foregroundStyle(Palette.ink)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("Profile")
        .task {
            await store.loadProducts()
            trialDays = await store.freeTrialDays(for: .annual)
        }
        .sheet(isPresented: $showsEditProfile) { EditProfileSheet() }
        .sheet(isPresented: $showsPrivacy) { PrivacySheet() }
        .fullScreenCover(item: $paywall) { PaywallView(context: $0) }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .alert("Add a phrase", isPresented: $isAddingPhrase) {
            TextField("Hey fam", text: $newPhrase)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let phrase = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
                if profile.addPhrase(phrase) {
                    toast.show(String(localized: "Added “\(phrase)” — AI will use it"))
                }
            }
        } message: {
            Text("Something you always say. The AI weaves it into new scripts.")
        }
    }

    private var proBackground: some ShapeStyle {
        LinearGradient(
            colors: [Palette.acc.opacity(0.18), Palette.acc.opacity(0.04), Palette.surface],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack { ProfileView() }
        .previewEnvironment()
}
#endif
