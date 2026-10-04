//
//  SampleScripts.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Scripts from the design, for previews and UI tests. Never shipped.
enum SampleScripts {
    static let morningHabits = Script(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "3 morning habits that changed my life",
        text: """
        Okay, real talk. [pause] Three tiny habits completely changed my mornings — and none of them take more than five minutes.

        Number one: I don't touch my phone for the first twenty minutes. No emails, no scrolling. Just water and daylight.

        Number two: I write down one thing. Not a to-do list — one thing that would make today a win. [smile]

        Number three: I move. Ten squats, a quick stretch, a walk around the block. Anything that gets the blood going.

        That's it. Try it for a week and tell me in the comments what changed. [look at camera] And follow for part two — my night routine is next.
        """,
        platform: .tiktok, type: .list,
        createdAt: .now.addingTimeInterval(-7200), updatedAt: .now.addingTimeInterval(-7200)
    )

    static let lampReview = Script(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Unboxing the Lumen desk lamp",
        text: """
        This lamp has been on my desk for two weeks, and I have thoughts. [pause]

        First — the light. Warm when you want it, crisp when you need to focus, and it never flickers on camera.

        Second — it folds flat. Like, actually flat. [show lamp]

        Is it worth it? If you film at your desk, yes. Link's in my bio.
        """,
        platform: .reels, type: .review, version: 2,
        createdAt: .now.addingTimeInterval(-86_400), updatedAt: .now.addingTimeInterval(-86_400)
    )

    static let sponsoredRead = Script(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        title: "Oat & Co. — sponsored read",
        text: """
        Stop buying oat milk that does this. [pause]

        I've been making my morning coffee with Oat & Co. barista blend for a month, and it foams better than anything I've tried.

        Watch this pour. [demo]

        Use code MORNING for twenty percent off your first order. [look at camera] This video is a paid partnership.
        """,
        platform: .tiktok, type: .ad,
        createdAt: .now.addingTimeInterval(-3 * 86_400), updatedAt: .now.addingTimeInterval(-3 * 86_400)
    )

    static let weeklyQA = Script(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        title: "Weekly Q&A — episode 12",
        text: """
        Welcome back to the weekly Q&A! [smile] You sent in over two hundred questions this week, so let's get right into it.

        First, from Maya: how do you stay consistent when you don't feel like filming? Honestly — I lower the bar. Some days the goal is one take, no edits.

        Next, from Jordan: what gear do I actually use? A phone, a cheap light, and this teleprompter. That's it. [pause]

        Last one for today: how long does a video take me? About an hour, start to finish, for something like this.

        If you've got questions for next week, drop them in the comments. See you then.
        """,
        platform: .youtube, type: .opinion,
        createdAt: .now.addingTimeInterval(-8 * 86_400), updatedAt: .now.addingTimeInterval(-8 * 86_400)
    )

    static let brandDeals = Script(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        title: "What 100 brand deals taught me",
        text: """
        [confident] After a hundred brand deals, here's what I'd tell my younger self. [pause]

        The brief is not the boss. Your audience is.

        The best-performing ads I made never sounded like ads. [emphasis] They sounded like me.

        What's the one thing you'd tell a creator doing their first deal?
        """,
        platform: .linkedin, type: .opinion,
        createdAt: .now.addingTimeInterval(-90_000), updatedAt: .now.addingTimeInterval(-90_000)
    )

    /// A draft (left without Done): it shows under DRAFTS, with "Continue ›".
    static let coldShowers = Script(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        title: "Cold showers: one month in",
        text: "Okay, so I did cold showers for thirty days.",
        platform: .shorts, type: .story,
        createdAt: .now.addingTimeInterval(-5 * 3600), updatedAt: .now.addingTimeInterval(-5 * 3600), isFinished: false
    )

    static let all = [morningHabits, lampReview, brandDeals, sponsoredRead, weeklyQA, coldShowers]
}
#endif
