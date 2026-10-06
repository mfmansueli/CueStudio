//
//  AccountSection.swift
//  Cue Studio
//

import AuthenticationServices
import SwiftUI

/// Sign in with Apple, optional like everything about an account: nothing in Cue needs one. It fills an empty profile name the first time.
struct AccountSection: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(SessionService.self) private var session
    @Environment(ToastService.self) private var toast

    var body: some View {
        Section {
            if session.isSignedIn {
                Button("Sign out", role: .destructive) {
                    session.signOut()
                    toast.show(String(localized: "Signed out"))
                }
                .cardRowBackground()
                .accessibilityIdentifier("profile.signOutButton")
            } else {
                SignInWithAppleButton(.signIn, onRequest: { $0.requestedScopes = [.fullName, .email] }, onCompletion: signedIn)
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: Metrics.buttonHeight)
                    .clipShape(Capsule())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .accessibilityIdentifier("profile.signInButton")
            }
        } footer: {
            Text(session.isSignedIn ? "Signed in with Apple" : "Optional. Nothing in Cue needs an account.")
        }
    }

    /// Apple sends the name only on the first sign-in; it fills an empty name.
    private func signedIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let name = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            session.signIn(userID: credential.user, name: name, email: credential.email)
            if profile.profile.name.isEmpty, let name, !name.isEmpty { profile.profile.name = name }
            toast.show(String(localized: "Signed in with Apple"))
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { toast.show(String(localized: "Couldn't sign in · Try again")) }
        }
    }
}
