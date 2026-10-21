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

    /// A card, quiet on purpose (nothing in Cue needs an account): what signing in does, then Apple's own button (white, the style Apple
    /// asks for on a dark background), a little shorter than the app's buttons; signed in, who and Sign out.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.isSignedIn ? "Signed in with Apple" : "Optional. Nothing in Cue needs an account; signing in only fills your name.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if session.isSignedIn {
                Button(role: .destructive) {
                    Haptics.medium()
                    session.signOut()
                    toast.show(String(localized: "Signed out"))
                } label: {
                    Text("Sign out")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .overlay(Capsule().strokeBorder(Palette.dangerText, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .foregroundStyle(Palette.dangerText)
                .accessibilityIdentifier("profile.signOutButton")
            } else {
                SignInWithAppleButton(.signIn, onRequest: { $0.requestedScopes = [.fullName, .email] }, onCompletion: signedIn)
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 46)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("profile.signInButton")
            }
        }
        .padding(16)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
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
