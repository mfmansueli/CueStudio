//
//  ProfileView.swift
//  Cue Studio
//

import AuthenticationServices
import StoreKit
import SwiftUI

/// The creator card (Sign in with Apple is optional), Creator Voice, Creator Setup, the plan and
/// settings.
struct ProfileView: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(StoreManager.self) private var store
    @Environment(SessionService.self) private var session
    @Environment(ToastService.self) private var toast
    @Environment(PreferencesService.self) private var preferences
    @Environment(AudioInputManager.self) private var audio
    @Environment(LanguageService.self) private var languages

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
                SoundsLikeYouCard()
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Creator Voice")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.ink)
                    Text("Your AI identity. Cue writes and rewrites every script to sound like you — on every platform.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                }
                .textCase(nil)
                .padding(.bottom, 4)
            }
            .listRowBackground(glow)
            Section {
                CreatorVoiceSection(
                    onAddPhrase: {
                        newPhrase = ""
                        isAddingPhrase = true
                    }
                )
            }
            Section {
                NavigationLink {
                    CreatorSetupView(preferences: preferences, microphones: audio, toast: toast)
                } label: {
                    creatorSetupRow
                }
                .accessibilityIdentifier("profile.creatorSetupButton")
            } header: {
                Text("Creator Setup")
                    .font(.title2.bold())
                    .foregroundStyle(Palette.ink)
                    .textCase(nil)
            } footer: {
                Text("Set it up once. Cue remembers how you create.")
            }
            Section {
                PlanSection(
                    trialDays: trialDays,
                    onUpgrade: { paywall = .profile },
                    onManage: { showsManageSubscriptions = true }
                )
            }
            .listRowBackground(store.tier.isPro ? AnyView(glow) : AnyView(Palette.surface))
            Section("Settings") {
                NavigationLink(value: ProfileRoute.languageRegion) {
                    HStack(spacing: 12) {
                        Text("Language & Region").foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Text(verbatim: languages.interfaceLanguage.nativeName)
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(1)
                    }
                }
                .accessibilityIdentifier("profile.languageRegionButton")
                Picker("Default “Create for”", selection: $profile.profile.defaultPlatform) {
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
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.ink3)
                    }
                }
                NavigationLink(value: ProfileRoute.acknowledgements) {
                    Text("Acknowledgements").foregroundStyle(Palette.ink)
                }
                .accessibilityIdentifier("profile.acknowledgementsButton")
                Button("Restore purchases") {
                    Task {
                        let restored = await store.restore()
                        toast.show(restored ? String(localized: "Purchases restored") : String(localized: "No purchases to restore"))
                    }
                }
                .foregroundStyle(Palette.ink)
            }
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

    /// "4K · 9:16 · Front · Large text": the usual setup at a glance.
    private var creatorSetupRow: some View {
        let setup = preferences.creatorSetup
        return HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(Palette.acc)
                .frame(width: 28, height: 28)
                .background(Palette.accSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Recording, teleprompter & remote")
                    .foregroundStyle(Palette.ink)
                Text(setup.summary(of: [.camera, .format, .quality, .textSize]))
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// Behind "Sounds like you" and the Pro plan.
    private var glow: some View {
        Palette.surface.overlay(
            LinearGradient(
                stops: [.init(color: Palette.accGlow, location: 0), .init(color: Palette.accGlowFaint, location: 0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack { ProfileView() }
        .previewEnvironment()
}
#endif
