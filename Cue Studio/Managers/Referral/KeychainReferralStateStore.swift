//
//  KeychainReferralStateStore.swift
//  Cue Studio
//

import Foundation
import os
import Security

/// The invites' state in the Keychain (`ReferralLocalState`), like the free exports' count: it survives deleting and reinstalling Cue, so a
/// reinstall neither makes a new install for the server nor credits a friend twice. This device only, readable after the first unlock.
final class KeychainReferralStateStore: ReferralStateStoring {
    struct Unreadable: Error {}

    private let service: String
    private let account = "referral"
    private let logger = Logger(subsystem: "studio.cue", category: "Referral")

    init(service: String = "studio.cue.usage") {
        self.service = service
    }

    func load() throws -> ReferralLocalState? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            logger.error("Could not read the invites: \(status)")
            throw Unreadable()
        }
        return try? JSONDecoder().decode(ReferralLocalState.self, from: data)
    }

    func save(_ state: ReferralLocalState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        var status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        if status != errSecSuccess {
            logger.error("Could not save the invites: \(status)")
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
