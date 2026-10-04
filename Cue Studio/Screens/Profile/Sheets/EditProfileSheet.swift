//
//  EditProfileSheet.swift
//  Cue Studio
//

import AuthenticationServices
import SwiftUI

/// The first block of Profile, opened: name and handle (kept on this iPhone), the defaults new scripts start from, and the
/// optional Sign in with Apple (or Sign out).
struct EditProfileSheet: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(SessionService.self) private var session
    @Environment(ToastService.self) private var toast
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var profile = profile
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $profile.profile.name)
                        .textContentType(.name)
                        .accessibilityIdentifier("editProfile.nameField")
                    HStack(spacing: 2) {
                        Text("@").foregroundStyle(Palette.ink2)
                        TextField("handle", text: $profile.profile.handle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                    }
                } footer: {
                    Text("Shown only on this device.")
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
                    if session.isSignedIn {
                        Button("Sign out", role: .destructive) {
                            session.signOut()
                            toast.show(String(localized: "Signed out"))
                        }
                        .accessibilityIdentifier("profile.signOutButton")
                    } else {
                        SignInWithAppleButton(.signIn, onRequest: { $0.requestedScopes = [.fullName, .email] }, onCompletion: signedIn)
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: Metrics.buttonHeight)
                            .clipShape(Capsule())
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .accessibilityIdentifier("profile.signInButton")
                    }
                } footer: {
                    Text(session.isSignedIn ? "Signed in with Apple" : "Optional. Nothing in Cue needs an account.")
                }
            }
            .navigationTitle("Your profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
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
                toast.show(String(localized: "Couldn't sign in · Try again"))
            }
        }
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) { EditProfileSheet() }
        .previewEnvironment()
}
#endif
