//
//  EditProfileAccount.swift
//  Cue Studio
//

import AuthenticationServices
import SwiftUI

/// Sign in with Apple in Edit Profile, optional like everything about an account: nothing in Cue needs one. It fills an empty profile name the first
/// time. Unlike the rest of the sheet it acts at once (signing in or out isn't something Done decides).
struct EditProfileAccount: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(SessionService.self) private var session
    @Environment(ToastService.self) private var toast

    /// The name Apple sent, for the draft of the sheet to show when it is still empty.
    var onName: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.isSignedIn {
                Button(role: .destructive) {
                    session.signOut()
                    toast.show(String(localized: "Signed out"))
                } label: {
                    Text("Sign out")
                        .font(.system(size: 17))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("profile.signOutButton")
            } else {
                SignInWithAppleButton(.signIn, onRequest: { $0.requestedScopes = [.fullName, .email] }, onCompletion: signedIn)
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: Metrics.buttonHeight)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("profile.signInButton")
            }
            Text(session.isSignedIn ? "Signed in with Apple" : "Optional. Nothing in Cue needs an account.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 16)
        }
    }

    /// Apple sends the name only on the first sign-in; it fills an empty name.
    private func signedIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let name = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            session.signIn(userID: credential.user, name: name, email: credential.email)
            if profile.profile.name.isEmpty, let name, !name.isEmpty {
                profile.profile.name = name
                onName(name)
            }
            toast.show(String(localized: "Signed in with Apple"))
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { toast.show(String(localized: "Couldn't sign in · Try again")) }
        }
    }
}
