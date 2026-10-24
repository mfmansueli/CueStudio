//
//  SpeechLocaleReservation.swift
//  Cue Studio
//

import Foundation
import os
import Speech

/// Keeps a language's speech model allocated to the app. The system lets an app hold only a few
/// languages at once (`AssetInventory.maximumReservedLocales`, five): past that, listening in a new
/// one fails with "Too many allocated locales". Every way of listening (Voice Following, dictation,
/// captions, Clean Up) reserves the language it needs through here, and when the places are taken the
/// language used longest ago makes room, so a new language still works and one that was heard before never
/// blocks another. Measured on an iPhone: after Voice Following had been used in five languages,
/// captions in a sixth failed until captions reserved too.
///
/// "Longest ago" is kept here, and room is made before reserving, measured on an iPhone with people's voices:
/// the system lists its languages in a different order each time (its first was any of them), and reserving a
/// sixth releases one of its own choosing. That released German while a take was being compared in Portuguese,
/// English, Spanish and German: a released language's model reads as not on the iPhone until it is installed
/// again, so the take was never heard as German.
nonisolated enum SpeechLocaleReservation {
    /// The languages reserved through here since launch, used longest ago first.
    private static let used = OSAllocatedUnfairLock<[String]>(initialState: [])

    /// Marks languages about to be used as just used, so reserving the first of them never makes room with another (a take
    /// compared in several languages).
    static func willUse(_ locales: [Locale]) {
        let codes = locales.map { $0.identifier(.bcp47) }
        used.withLock { order in
            order.removeAll { codes.contains($0) }
            order += codes
        }
    }

    static func reserve(_ locale: Locale) async {
        let code = locale.identifier(.bcp47)
        let order = used.withLock { order in
            order.removeAll { $0 == code }
            order.append(code)
            return order
        }
        let reserved = await AssetInventory.reservedLocales
        guard !reserved.contains(where: { $0.identifier(.bcp47) == code }) else { return }
        if reserved.count >= AssetInventory.maximumReservedLocales,
           let room = toRelease(from: reserved.map { $0.identifier(.bcp47) }, making: code, usedInOrder: order),
           let oldest = reserved.first(where: { $0.identifier(.bcp47) == room }) {
            await AssetInventory.release(reservedLocale: oldest)
        }
        _ = try? await AssetInventory.reserve(locale: locale)
    }

    /// Which of the `reserved` languages makes room for `code`: one not used since launch first, else the one used longest
    /// ago; never `code` itself, nor another variant of its language while there is any other: Simplified and Traditional
    /// Chinese share a model, and releasing zh-CN to make room for zh-TW left zh-TW's model reading as not on the iPhone.
    static func toRelease(from reserved: [String], making code: String, usedInOrder order: [String]) -> String? {
        let language = code.prefix { $0 != "-" }
        let others = reserved.filter { $0 != code }
        let unrelated = others.filter { $0.prefix { $0 != "-" } != language }
        return (unrelated.isEmpty ? others : unrelated).min { (order.firstIndex(of: $0) ?? -1) < (order.firstIndex(of: $1) ?? -1) }
    }
}
