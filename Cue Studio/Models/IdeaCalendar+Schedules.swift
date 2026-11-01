//
//  IdeaCalendar+Schedules.swift
//  Cue Studio
//

import Foundation

nonisolated extension IdeaCalendar {
    private static let sunday = 1, monday = 2, thursday = 5, saturday = 7

    /// Where the Western calendar's feasts are days people plan around (the Americas and Europe).
    private static let western: Set<String> = [
        "BR", "PT", "US", "GB", "IE", "CA", "AU", "NZ", "ES", "MX", "AR", "CO", "CL", "PE", "FR", "DE", "AT", "CH", "IT", "NL", "BE", "DK", "NO",
        "SE", "FI", "PL",
    ]
    /// Where the lunar calendar's festivals are kept.
    private static let lunar: Set<String> = ["CN", "TW", "HK", "MO", "KR", "VN", "SG", "MY"]
    /// Where Ramadan and Eid are.
    private static let islamic: Set<String> = ["SA", "AE", "EG", "ID", "TR", "MY", "MA", "JO", "QA", "KW", "BH", "OM", "DZ", "TN", "PK"]
    /// Where neither Christmas nor Black Friday is a day people plan videos around.
    private static let noChristmas: Set<String> = ["SA", "AE", "EG", "TR", "CN", "QA", "KW", "BH", "OM", "PK", "DZ", "MA", "TN", "JO"]

    private static func only(_ regions: Set<String>, _ rule: Rule) -> [String: Rule] {
        Dictionary(uniqueKeysWithValues: regions.map { ($0, rule) })
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func schedule(of kind: IdeaOccasion.Kind) -> Schedule {
        switch kind {
        case .newYear:
            return Schedule(everywhere: .fixed(month: 1, day: 1))
        case .lunarNewYear:
            return Schedule(regions: only(lunar.union(["ID"]), .chinese(month: 1, day: 1)))
        case .valentines:
            return Schedule(everywhere: .fixed(month: 2, day: 14), regions: ["BR": .fixed(month: 6, day: 12)], except: islamic)
        case .carnival:
            return Schedule(regions: only(["BR", "PT"], .easter(plus: -47)))
        case .womensDay:
            return Schedule(everywhere: .fixed(month: 3, day: 8), except: ["SA", "QA", "KW", "BH", "OM", "PK"])
        case .easter:
            return Schedule(regions: only(western, .easter(plus: 0)))
        case .ramadan:
            return Schedule(regions: only(islamic, .islamic(month: 9, day: 1)))
        case .eidAlFitr:
            return Schedule(regions: only(islamic, .islamic(month: 10, day: 1)))
        case .childrensDay:
            return Schedule(regions: [
                "BR": .fixed(month: 10, day: 12), "PT": .fixed(month: 6, day: 1), "MX": .fixed(month: 4, day: 30),
                "AR": .weekday(ordinal: 3, weekday: sunday, month: 8), "JP": .fixed(month: 5, day: 5), "KR": .fixed(month: 5, day: 5),
                "CN": .fixed(month: 6, day: 1), "TW": .fixed(month: 4, day: 4), "VN": .fixed(month: 6, day: 1), "TR": .fixed(month: 4, day: 23),
                "IN": .fixed(month: 11, day: 14), "ID": .fixed(month: 7, day: 23), "TH": .weekday(ordinal: 2, weekday: saturday, month: 1),
            ])
        case .mothersDay:
            return Schedule(
                everywhere: .weekday(ordinal: 2, weekday: sunday, month: 5),
                regions: [
                    "PT": .weekday(ordinal: 1, weekday: sunday, month: 5), "ES": .weekday(ordinal: 1, weekday: sunday, month: 5),
                    "MX": .fixed(month: 5, day: 10), "GB": .easter(plus: -21), "IE": .easter(plus: -21),
                    "FR": .weekday(ordinal: -1, weekday: sunday, month: 5), "SE": .weekday(ordinal: -1, weekday: sunday, month: 5),
                    "NO": .weekday(ordinal: 2, weekday: sunday, month: 2), "AR": .weekday(ordinal: 3, weekday: sunday, month: 10),
                    "KR": .fixed(month: 5, day: 8), "TH": .fixed(month: 8, day: 12), "ID": .fixed(month: 12, day: 22),
                    "SA": .fixed(month: 3, day: 21), "AE": .fixed(month: 3, day: 21), "EG": .fixed(month: 3, day: 21), "JO": .fixed(month: 3, day: 21),
                ],
                except: ["PK", "QA", "KW", "BH", "OM"]
            )
        case .fathersDay:
            return Schedule(
                everywhere: .weekday(ordinal: 3, weekday: sunday, month: 6),
                regions: [
                    "BR": .weekday(ordinal: 2, weekday: sunday, month: 8), "PT": .fixed(month: 3, day: 19), "ES": .fixed(month: 3, day: 19),
                    "IT": .fixed(month: 3, day: 19), "DE": .easter(plus: 39), "AT": .weekday(ordinal: 2, weekday: sunday, month: 6),
                    "BE": .weekday(ordinal: 2, weekday: sunday, month: 6), "CH": .weekday(ordinal: 1, weekday: sunday, month: 6),
                    "AU": .weekday(ordinal: 1, weekday: sunday, month: 9), "NZ": .weekday(ordinal: 1, weekday: sunday, month: 9),
                    "SE": .weekday(ordinal: 2, weekday: sunday, month: 11), "NO": .weekday(ordinal: 2, weekday: sunday, month: 11),
                    "FI": .weekday(ordinal: 2, weekday: sunday, month: 11), "DK": .fixed(month: 6, day: 5), "TH": .fixed(month: 12, day: 5),
                    "TW": .fixed(month: 8, day: 8), "ID": .fixed(month: 11, day: 12),
                ],
                // Korea keeps one Parents' Day (Mother's Day here); the Gulf keeps neither.
                except: ["KR", "SA", "AE", "EG", "JO", "PK", "QA", "KW", "BH", "OM"]
            )
        case .festaJunina:
            return Schedule(regions: ["BR": .fixed(month: 6, day: 13)], isApproximate: true)
        case .backToSchool:
            var regions = only(["GB", "IE", "FR", "IT", "ES", "PT", "DE", "NL", "BE", "DK", "NO", "SE", "AT", "CH", "TR"], .fixed(month: 9, day: 1))
            regions.merge([
                "BR": .fixed(month: 2, day: 2), "US": .fixed(month: 8, day: 20), "CA": .fixed(month: 9, day: 2), "MX": .fixed(month: 8, day: 26),
                "AR": .fixed(month: 3, day: 1), "JP": .fixed(month: 4, day: 6), "KR": .fixed(month: 3, day: 2), "AU": .fixed(month: 1, day: 28),
                "NZ": .fixed(month: 2, day: 1), "IN": .fixed(month: 6, day: 15), "ID": .fixed(month: 7, day: 14), "VN": .fixed(month: 9, day: 5),
            ]) { _, own in own }
            return Schedule(regions: regions, isApproximate: true)
        case .midAutumn:
            return Schedule(regions: only(lunar, .chinese(month: 8, day: 15)))
        case .halloween:
            return Schedule(regions: only(["US", "CA", "GB", "IE"], .fixed(month: 10, day: 31)))
        case .dayOfTheDead:
            return Schedule(regions: ["MX": .fixed(month: 11, day: 2)])
        case .diwali:
            // Lakshmi Puja; the Hindu calendar isn't one of Foundation's, so the days are listed (and said only as "coming up").
            return Schedule(regions: ["IN": .listed(["2026-11-08", "2027-10-29", "2028-10-17", "2029-11-05", "2030-10-26"])], isApproximate: true)
        case .singlesDay:
            return Schedule(regions: ["CN": .fixed(month: 11, day: 11)])
        case .thanksgiving:
            return Schedule(regions: [
                "US": .weekday(ordinal: 4, weekday: thursday, month: 11), "CA": .weekday(ordinal: 2, weekday: monday, month: 10),
            ])
        case .blackFriday:
            return Schedule(everywhere: .weekday(ordinal: 4, weekday: thursday, month: 11, plus: 1), except: noChristmas)
        case .christmas:
            return Schedule(everywhere: .fixed(month: 12, day: 25), except: noChristmas)
        }
    }
}
