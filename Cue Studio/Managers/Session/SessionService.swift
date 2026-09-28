//
//  SessionService.swift
//  Cue Studio
//

import Foundation

/// The signed-in account (Sign in with Apple, the only login). The one place that knows about it:
/// screens read `account` and call `signIn` / `signOut`. Everything in Cue works signed out.
@MainActor
@Observable
final class SessionService {
    private(set) var account: AppleAccount?

    private let defaults: UserDefaults
    private let checker: AppleIDCredentialChecking

    init(defaults: UserDefaults = .standard, checker: AppleIDCredentialChecking = AppleIDCredentialChecker()) {
        self.defaults = defaults
        self.checker = checker
        if let data = defaults.data(forKey: DefaultsKey.appleAccount) {
            account = try? JSONDecoder().decode(AppleAccount.self, from: data)
        }
    }

    var isSignedIn: Bool { account != nil }

    /// Keeps the name and email Apple sent the first time; later sign-ins send only the ID.
    func signIn(userID: String, name: String?, email: String?) {
        let known = account?.userID == userID ? account : nil
        account = AppleAccount(
            userID: userID,
            name: name?.isEmpty == false ? name : known?.name,
            email: email?.isEmpty == false ? email : known?.email
        )
        persist()
    }

    func signOut() {
        account = nil
        defaults.removeObject(forKey: DefaultsKey.appleAccount)
    }

    /// Signs out when the account was revoked or removed. Call at launch.
    func verify() async {
        guard let account else { return }
        if await checker.wasRevoked(userID: account.userID) {
            signOut()
        }
    }

    private func persist() {
        guard let account, let data = try? JSONEncoder().encode(account) else { return }
        defaults.set(data, forKey: DefaultsKey.appleAccount)
    }
}
