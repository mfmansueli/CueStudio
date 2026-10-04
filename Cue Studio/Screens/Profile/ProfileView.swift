//
//  ProfileView.swift
//  Cue Studio
//

import AuthenticationServices
import StoreKit
import SwiftUI

/// Identity, My Cue Voice, creative preferences and the plan. Sign in with Apple is optional.
struct ProfileView: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(StoreManager.self) private var store
    @Environment(SessionService.self) private var session
    @Environment(ToastService.self) private var toast

    @State private var showsEditProfile = false
    @State private var showsManageSubscriptions = false
    @State private var paywall: PaywallContext?
    @State private var isAddingPhrase = false
    @State private var newPhrase = ""
    @State private var trialDays: Int?
    /// The My Cue Voice questions opened from the card (all that is missing, or one row to edit).
    @State private var voiceSetup: ProfileVoiceSetup?

    /// Something of this screen's own covers it: the moving light behind "Sounds like you" rests.
    private var isCovered: Bool {
        showsEditProfile || paywall != nil || showsManageSubscriptions || voiceSetup != nil
    }

    var body: some View {
        @Bindable var profile = profile
        List {
            Section {
                Button { showsEditProfile = true } label: {
                    CreatorCard(profile: profile.profile, isPro: store.tier.isPro, isSignedIn: session.isSignedIn)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.creatorCard")
                if !session.isSignedIn {
                    SignInWithAppleButton(.signIn, onRequest: { $0.requestedScopes = [.fullName, .email] }, onCompletion: signedIn)
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: Metrics.buttonHeight)
                        .clipShape(Capsule())
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .accessibilityIdentifier("profile.signInButton")
                }
            }
            Section {
                MyCueVoiceCard(setup: $voiceSetup)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Cue Voice")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.ink)
                    Text("Your AI identity. Cue writes and rewrites every script to sound like you — on every platform.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                }
                .textCase(nil)
                .padding(.bottom, 4)
            }
            .listRowBackground(AuroraCardBackground(base: Palette.surface, isActive: !isCovered))
            Section {
                CreatorVoiceSection(
                    onAddPhrase: {
                        newPhrase = ""
                        isAddingPhrase = true
                    }
                )
            }
            Section("Creator preferences") {
                Picker("Default “Create for”", selection: $profile.profile.defaultPlatform) {
                    ForEach(Platform.allCases) { Text($0.destinationName).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Palette.ink2)
                .accessibilityIdentifier("profile.defaultPlatformPicker")
                Toggle("Monetization goals", isOn: $profile.profile.monetizationGoals)
                    .tint(Palette.successText)
                    .accessibilityIdentifier("profile.monetizationGoalsToggle")
            }
            Section {
                PlanSection(
                    trialDays: trialDays,
                    onUpgrade: { paywall = .profile },
                    onManage: { showsManageSubscriptions = true }
                )
            }
            .listRowBackground(NightAuroraBackground(yellowTouch: store.tier.isPro))
            if session.isSignedIn {
                Section {
                    Button("Sign out", role: .destructive) {
                        session.signOut()
                        toast.show(String(localized: "Signed out"))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("profile.signOutButton")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("Profile")
        .toolbarTitleDisplayMode(.inlineLarge)
        .task {
            await store.loadProducts()
            trialDays = await store.freeTrialDays(for: .annual)
        }
        .sheet(isPresented: $showsEditProfile) { EditProfileSheet() }
        .sheet(item: $voiceSetup) { setup in
            VoiceSetupSheet(mode: setup.mode, profile: profile.profile, startAt: setup.startAt)
        }
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

    /// Apple sends the name only on the first sign-in; it fills an empty profile name.
    private func signedIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let name = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            session.signIn(userID: credential.user, name: name, email: credential.email)
            if profile.profile.name.isEmpty, let name, !name.isEmpty {
                profile.profile.name = name
            }
            toast.show(String(localized: "Signed in with Apple"))
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                toast.show(String(localized: "Couldn't sign in with Apple. Try again."))
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { ProfileView() }
        .previewEnvironment()
}
#endif
