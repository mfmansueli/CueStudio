//
//  SpeechLocaleReservation.swift
//  Cue Studio
//

import Foundation
import Speech

/// Keeps a language's speech model allocated to the app. The system lets an app hold only a few
/// languages at once (`AssetInventory.maximumReservedLocales`, five): past that, listening in a new
/// one fails with "Too many allocated locales". Every way of listening (Voice Following, dictation,
/// captions, Clean Up) reserves the language it needs through here, and when the places are taken the
/// oldest other language makes room, so a new language still works and one that was heard before never
/// blocks another. Measured on an iPhone: after Voice Following had been used in five languages,
/// captions in a sixth failed until captions reserved too.
nonisolated enum SpeechLocaleReservation {
    static func reserve(_ locale: Locale) async {
        let reserved = await AssetInventory.reservedLocales
        guard !reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else { return }
        if (try? await AssetInventory.reserve(locale: locale)) == true { return }
        if reserved.count >= AssetInventory.maximumReservedLocales, let oldest = reserved.first {
            await AssetInventory.release(reservedLocale: oldest)
            _ = try? await AssetInventory.reserve(locale: locale)
        }
    }
}
