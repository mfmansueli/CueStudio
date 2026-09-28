//
//  KeychainExportCountStore.swift
//  Cue Studio
//

import Foundation
import os
import Security

/// Free exports used, kept in the Keychain: unlike UserDefaults it survives deleting and
/// reinstalling the app, so the five free exports can't be reset that way. This device only (never
/// synced), readable after the first unlock.
final class KeychainExportCountStore: ExportCountStoring {
    private let service: String
    private let account = "freeExportsUsed"
    private let logger = Logger(subsystem: "studio.cue", category: "ExportCount")

    init(service: String = "studio.cue.usage") {
        self.service = service
    }

    func load() -> Int {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = Int(String(decoding: data, as: UTF8.self))
        else { return 0 }
        return max(0, value)
    }

    func save(_ count: Int) {
        let data = Data(String(count).utf8)
        var status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        if status != errSecSuccess {
            logger.error("Could not save the export count: \(status)")
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
