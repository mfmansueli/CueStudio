//
//  ScriptType.swift
//  Cue Studio
//

import Foundation

/// The video formats creators post most. Each one carries its own structure.
nonisolated enum ScriptType: String, Codable, CaseIterable, Identifiable, Sendable {
    case ad, review, tutorial, list, story, opinion, launch, apology, mythFact, pov

    var id: String { rawValue }

    var label: String { structure.label }

    var summary: String {
        switch self {
        case .ad: String(localized: "Brand deal · UGC ad")
        case .review: String(localized: "Unboxing, first look")
        case .tutorial: String(localized: "How-to, step by step")
        case .list: String(localized: "“3 things that…”")
        case .story: String(localized: "Setup, twist, payoff")
        case .opinion: String(localized: "Opinion or comment reply")
        case .launch: String(localized: "Launch, drop, big news")
        case .apology: String(localized: "Serious — no hype")
        case .mythFact: String(localized: "Bust one belief")
        case .pov: String(localized: "Put the viewer in a moment")
        }
    }

    var structure: ScriptStructure {
        let generic = ScriptStructure.generic
        switch self {
        case .ad:
            return ScriptStructure(
                label: String(localized: "Sponsored ad"),
                blocks: [
                    String(localized: "Hook"), String(localized: "Problem"), String(localized: "Product"),
                    String(localized: "Proof"), String(localized: "Offer"),
                ],
                tones: [.energetic, .casual, .premium, .funny],
                tools: [.newHooks, .strongerCTA, .addDisclosure, .fitToTime],
                hooks: [
                    String(localized: "Stop buying the version that does this. [pause]"),
                    String(localized: "I found the only one that actually works."),
                    String(localized: "A friend made me try this — I owe her."),
                    String(localized: "POV: it finally looks like the ad."),
                ],
                isSerious: false
            )
        case .review:
            return ScriptStructure(
                label: String(localized: "Review"),
                blocks: [String(localized: "Hook"), String(localized: "First look"), String(localized: "Pros & cons"), String(localized: "Verdict")],
                tones: generic.tones, tools: generic.tools,
                hooks: [
                    String(localized: "Honest verdict, no sponsor."),
                    String(localized: "Is this worth the hype? Let's see."),
                    String(localized: "I didn't expect to like this one. [pause]"),
                    String(localized: "Don't buy this until you watch this."),
                ],
                isSerious: false
            )
        case .tutorial:
            return ScriptStructure(
                label: String(localized: "Tutorial"),
                blocks: [String(localized: "Hook"), String(localized: "Promise"), String(localized: "Steps"), String(localized: "CTA")],
                tones: generic.tones, tools: generic.tools,
                hooks: [
                    String(localized: "Here's the whole process in under a minute."),
                    String(localized: "Steal my system — it's simpler than you think."),
                    String(localized: "You're doing this wrong. Here's the fix. [pause]"),
                    String(localized: "Save this before you need it."),
                ],
                isSerious: false
            )
        case .list:
            return ScriptStructure(
                label: String(localized: "Tips / list"),
                blocks: [String(localized: "Hook"), String(localized: "Tips"), String(localized: "CTA")],
                tones: generic.tones, tools: generic.tools,
                hooks: [
                    String(localized: "Three tiny changes. Totally different results."),
                    String(localized: "I tried everything — these are the ones that stuck."),
                    String(localized: "This is hard because you skip this. [pause]"),
                    String(localized: "If you only change one thing tomorrow, make it this."),
                ],
                isSerious: false
            )
        case .story:
            return ScriptStructure(
                label: String(localized: "Storytime"),
                blocks: [String(localized: "Hook"), String(localized: "Setup"), String(localized: "Twist"), String(localized: "Payoff")],
                tones: generic.tones, tools: generic.tools,
                hooks: [
                    String(localized: "This is the most embarrassing thing that's happened to me."),
                    String(localized: "It went wrong at the worst possible moment."),
                    String(localized: "I almost didn't post this. [pause]"),
                    String(localized: "Story time — and yes, it ends well."),
                ],
                isSerious: false
            )
        case .opinion:
            return ScriptStructure(
                label: String(localized: "Hot take / reply"),
                blocks: [
                    String(localized: "Hook"),
                    String(inInterfaceLanguage: LocalizedStringResource(
                        "block.opinionTake", defaultValue: "Take",
                        comment: "The opinion format's block where the creator states their opinion (their “take”), not a recording."
                    )),
                    String(localized: "Why"),
                    String(localized: "Question"),
                ],
                tones: generic.tones, tools: generic.tools,
                hooks: [
                    String(localized: "Unpopular opinion, but hear me out."),
                    String(localized: "Someone asked this in the comments — let me answer."),
                    String(localized: "I'm going to get hate for this. [pause]"),
                    String(localized: "Can we talk about this for a second?"),
                ],
                isSerious: false
            )
        case .launch:
            return ScriptStructure(
                label: String(localized: "Announcement"),
                blocks: [String(localized: "Hook"), String(localized: "News"), String(localized: "Details"), String(localized: "CTA")],
                tones: generic.tones, tools: generic.tools,
                hooks: [
                    String(localized: "I've been keeping a secret. [pause]"),
                    String(localized: "It's finally happening."),
                    String(localized: "You asked for this — here it is."),
                    String(localized: "Big news. Stay till the end."),
                ],
                isSerious: false
            )
        case .apology:
            return ScriptStructure(
                label: String(localized: "Apology / statement"),
                blocks: [
                    String(localized: "Opening"), String(localized: "Acknowledge"), String(localized: "Own it"),
                    String(localized: "What changes"), String(localized: "Close"),
                ],
                tones: [.sincere, .calm, .direct],
                tools: [.moreHuman, .lessDefensive, .shorterAndDirect, .fixGrammar],
                hooks: [
                    String(localized: "I want to talk about last week, directly."),
                    String(localized: "Before anything else — I'm sorry."),
                    String(localized: "I owe you an explanation. [pause]"),
                    String(localized: "This video is overdue."),
                ],
                isSerious: true
            )
        case .mythFact:
            return ScriptStructure(
                label: String(localized: "Myth vs fact"),
                blocks: [
                    String(localized: "Myth"), String(localized: "Why people think it"), String(localized: "Fact"), String(localized: "CTA"),
                ],
                tones: generic.tones, tools: generic.tools,
                hooks: [
                    String(localized: "You've been told this your whole life. It's wrong. [pause]"),
                    String(localized: "Stop believing this one thing."),
                    String(localized: "Everyone repeats this myth. Here's the truth."),
                    String(localized: "I believed this for years — until I checked."),
                ],
                isSerious: false
            )
        case .pov:
            return ScriptStructure(
                label: String(localized: "POV"),
                blocks: [String(localized: "POV line"), String(localized: "Scene"), String(localized: "Twist")],
                tones: generic.tones, tools: generic.tools,
                hooks: [
                    String(localized: "POV: you finally hit record. [pause]"),
                    String(localized: "POV: it's 7 a.m. and the idea just landed."),
                    String(localized: "POV: your first video goes better than planned."),
                    String(localized: "POV: you're the one they all ask for advice."),
                ],
                isSerious: false
            )
        }
    }
}
