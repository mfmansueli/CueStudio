//
//  IdeaOccasion.swift
//  Cue Studio
//

import Foundation

/// A day a creator could tie a video to (Mother's Day, Black Friday, back to school…) where they live (`IdeaCalendar`): in the weeks before it,
/// one idea of a batch may be about it, and the card says so ("Coming up: Mother's Day").
nonisolated struct IdeaOccasion: Hashable, Codable, Sendable {
    enum Kind: String, CaseIterable, Codable, Sendable {
        case newYear, lunarNewYear, valentines, carnival, womensDay, easter, ramadan, eidAlFitr, childrensDay, mothersDay, fathersDay
        case festaJunina, backToSchool, midAutumn, halloween, dayOfTheDead, diwali, singlesDay, thanksgiving, blackFriday, christmas
    }

    let kind: Kind
    /// The day (its start, in the creator's calendar).
    let date: Date
    /// Only near, never a day the card or the model should name (a school year starts over a few weeks).
    let isApproximate: Bool

    /// What the creator reads.
    var name: String {
        switch kind {
        case .newYear: String(localized: "New Year", comment: "An occasion ideas can be tied to")
        case .lunarNewYear: String(localized: "Lunar New Year", comment: "An occasion ideas can be tied to")
        case .valentines: String(localized: "Valentine’s Day", comment: "An occasion ideas can be tied to (in Brazil, Dia dos Namorados on June 12)")
        case .carnival: String(localized: "Carnival", comment: "An occasion ideas can be tied to")
        case .womensDay: String(localized: "International Women’s Day", comment: "An occasion ideas can be tied to")
        case .easter: String(localized: "Easter", comment: "An occasion ideas can be tied to")
        case .ramadan: String(localized: "Ramadan", comment: "An occasion ideas can be tied to")
        case .eidAlFitr: String(localized: "Eid al-Fitr", comment: "An occasion ideas can be tied to")
        case .childrensDay: String(localized: "Children’s Day", comment: "An occasion ideas can be tied to")
        case .mothersDay: String(localized: "Mother’s Day", comment: "An occasion ideas can be tied to")
        case .fathersDay: String(localized: "Father’s Day", comment: "An occasion ideas can be tied to")
        case .festaJunina: String(localized: "Festa Junina", comment: "An occasion ideas can be tied to (Brazil's June festivals)")
        case .backToSchool: String(localized: "Back to school", comment: "An occasion ideas can be tied to")
        case .midAutumn: String(localized: "Mid-Autumn Festival", comment: "An occasion ideas can be tied to")
        case .halloween: String(localized: "Halloween", comment: "An occasion ideas can be tied to")
        case .dayOfTheDead: String(localized: "Day of the Dead", comment: "An occasion ideas can be tied to (Mexico)")
        case .diwali: String(localized: "Diwali", comment: "An occasion ideas can be tied to")
        case .singlesDay: String(localized: "Singles’ Day", comment: "An occasion ideas can be tied to (China, November 11)")
        case .thanksgiving: String(localized: "Thanksgiving", comment: "An occasion ideas can be tied to")
        case .blackFriday: String(localized: "Black Friday", comment: "An occasion ideas can be tied to")
        case .christmas: String(localized: "Christmas", comment: "An occasion ideas can be tied to")
        }
    }

    /// What the model reads, in English whatever the interface language is.
    var promptName: String {
        switch kind {
        case .newYear: "New Year"
        case .lunarNewYear: "Lunar New Year"
        case .valentines: "Valentine's Day"
        case .carnival: "Carnival"
        case .womensDay: "International Women's Day"
        case .easter: "Easter"
        case .ramadan: "the start of Ramadan"
        case .eidAlFitr: "Eid al-Fitr"
        case .childrensDay: "Children's Day"
        case .mothersDay: "Mother's Day"
        case .fathersDay: "Father's Day"
        case .festaJunina: "Festa Junina (Brazil's June festivals)"
        case .backToSchool: "the start of the school year"
        case .midAutumn: "the Mid-Autumn Festival"
        case .halloween: "Halloween"
        case .dayOfTheDead: "the Day of the Dead"
        case .diwali: "Diwali"
        case .singlesDay: "Singles' Day (November 11 shopping day)"
        case .thanksgiving: "Thanksgiving"
        case .blackFriday: "Black Friday"
        case .christmas: "Christmas"
        }
    }

    /// When it is, as the model reads it: "on May 10", or "coming up" for an approximate one.
    var promptWhen: String {
        guard !isApproximate else { return "coming up" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d"
        return "on " + formatter.string(from: date)
    }
}
