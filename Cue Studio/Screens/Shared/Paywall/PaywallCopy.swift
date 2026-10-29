//
//  PaywallCopy.swift
//  Cue Studio
//

import Foundation

/// Paywall wording. Kept free of StoreKit types so it can be tested; prices come in as display strings.
nonisolated enum PaywallCopy {
    static func title(for context: PaywallContext) -> String {
        switch context {
        case .export: String(localized: "Keep sharing your universe.")
        case .profile: String(localized: "Take your universe further.")
        case .ultra: String(localized: "Keep writing with Ultra AI.")
        }
    }

    /// The small line above the title: the plans' name, or (when the video is waiting) that it is ready.
    static func eyebrow(for context: PaywallContext) -> String {
        switch context {
        case .export: String(localized: "YOUR VIDEO IS READY")
        case .profile: String(localized: "CUE PRO")
        case .ultra: String(localized: "ULTRA AI")
        }
    }

    /// - Parameter ultraIsOffered: Ultra AI is offered on this iPhone (its free scripts are part of trying Cue).
    static func subtitle(for context: PaywallContext, ultraIsOffered: Bool = false) -> String {
        switch context {
        case .export:
            String(localized: "Start the trial and export it now.")
        case .profile:
            ultraIsOffered ? freeToTryWithUltra : freeToTry
        case .ultra:
            // The trial has the free scripts only (owner, 29/10/2026): said here, before anyone starts it for Ultra AI.
            String(localized: "Your \(UsagePolicy.freeUltraScripts) free scripts are written. Cue Pro adds \(UsagePolicy.proUltraScriptsPerMonth) a month, from the first paid month.")
        }
    }

    /// What Pro offers, as the board lists it (11.4).
    static let benefits: [ProBenefit] = [
        ProBenefit(symbol: "square.and.arrow.up", text: String(localized: "Unlimited exports, up to 4K"), tag: String(localized: "EXPORT"), tone: .plain),
        ProBenefit(symbol: "waveform", text: String(localized: "Full My Cue Voice + sponsored-ad drafts"), tag: String(localized: "AI"), tone: .ai),
        ProBenefit(
            symbol: "wand.and.stars", text: String(localized: "Hook variations, platform versions, best-take picks"), tag: String(localized: "AI"), tone: .ai
        ),
        ProBenefit(
            symbol: "paintpalette", text: String(localized: "Cover styles, series tags, “Text behind me”"), tag: String(localized: "EDIT"), tone: .plain
        ),
        ProBenefit(
            symbol: "applewatch", text: String(localized: "Remote from Apple Watch, iPad & Mac sync"), tag: String(localized: "STUDIO"), tone: .plain,
            isAvailable: false
        ),
        ProBenefit(symbol: "sparkle", text: String(localized: "Every milestone app icon"), tag: String(localized: "UNIVERSE"), tone: .universe),
    ]

    /// Ultra AI's monthly scripts, second in the list where Ultra AI is offered (it doesn't need Apple Intelligence).
    static let ultraBenefit = ProBenefit(
        symbol: "sparkles", text: String(localized: "\(UsagePolicy.proUltraScriptsPerMonth) Ultra AI scripts a month"), tag: String(localized: "AI"),
        tone: .ai
    )

    /// The lines for this iPhone: the ones about AI stay out where Apple Intelligence can't run, and the ones for what the app cannot do yet stay out
    /// (the Apple Watch and Mac remote), so the paywall never sells what is not there. Ultra AI's line is there only where Ultra AI is offered.
    static func visibleBenefits(aiIsAvailable: Bool, ultraIsOffered: Bool = false) -> [ProBenefit] {
        var lines = benefits.filter { $0.isAvailable && (aiIsAvailable || $0.tone != .ai) }
        if ultraIsOffered { lines.insert(ultraBenefit, at: min(1, lines.count)) }
        return lines
    }

    /// The line under the title of the regular Pro.
    static var freeToTry: String {
        String(localized: "Free to try · \(UsagePolicy.freeExports) exports included. Then 7 days free.")
    }

    /// The same, where Ultra AI is offered: its free scripts are part of trying Cue.
    static var freeToTryWithUltra: String {
        String(localized: "Free to try · \(UsagePolicy.freeExports) exports and \(UsagePolicy.freeUltraScripts) Ultra AI scripts included. Then 7 days free.")
    }

    static func welcome(for context: PaywallContext, startedTrial: Bool) -> String {
        switch context {
        case .export:
            if startedTrial {
                String(localized: "Trial started · video exported")
            } else {
                String(localized: "Welcome to Cue Pro · video exported")
            }
        case .profile:
            if startedTrial {
                String(localized: "Trial started · Enjoy Cue Pro")
            } else {
                String(localized: "Welcome to Cue Pro")
            }
        case .ultra:
            if startedTrial {
                String(localized: "Trial started · Ultra AI’s monthly scripts start with the first paid month")
            } else {
                String(localized: "Welcome to Cue Pro · \(UsagePolicy.proUltraScriptsPerMonth) Ultra AI scripts this month")
            }
        }
    }

    /// "$39.99", or an ellipsis while the price loads.
    static func priceOnly(displayPrice: String?) -> String { displayPrice ?? "…" }

    static func price(for plan: ProPlan, displayPrice: String?) -> String {
        let price = displayPrice ?? "…"
        return switch plan {
        case .annual: String(localized: "\(price) / year")
        case .monthly: String(localized: "\(price) / month")
        }
    }

    static func callToAction(for plan: ProPlan, displayPrice: String?, trialDays: Int?, context: PaywallContext = .profile) -> String {
        if context == .export, trialDays != nil { return String(localized: "Start free trial · export now") }
        if let trialDays { return String(localized: "Start \(trialDays)-day free trial") }
        let price = displayPrice ?? "…"
        return switch plan {
        case .annual: String(localized: "Subscribe for \(price)/year")
        case .monthly: String(localized: "Subscribe for \(price)/month")
        }
    }

    static func finePrint(for plan: ProPlan, displayPrice: String?, trialDays: Int?) -> String {
        let price = displayPrice ?? "…"
        switch plan {
        case .annual:
            if let trialDays {
                return String(localized: "Free for \(trialDays) days, then \(price)/year. Cancel anytime in Settings.")
            }
            return String(localized: "Renews yearly at \(price). Cancel anytime in Settings.")
        case .monthly:
            if let trialDays {
                return String(localized: "Free for \(trialDays) days, then \(price)/month. Cancel anytime in Settings.")
            }
            return String(localized: "Renews monthly at \(price). Cancel anytime in Settings.")
        }
    }

    static func savingsBadge(percent: Int?) -> String? {
        guard let percent, percent > 0 else { return nil }
        return String(localized: "SAVE \(percent)%")
    }
}
