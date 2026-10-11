//
//  ThemeCatalog.swift
//  Cue Studio
//

import Foundation

/// Starter ideas, shown before (or without) the model's own: on the card's ↻ until the first ideas arrive, and in Find inspiration. Each is a
/// whole brief, like the model's (a headline, the angle to take and a first sentence to say), so the roulette's card reads the same whether
/// Apple Intelligence wrote it or not. Local on purpose: they are starting points, never presented as trends (trends in real time would need a
/// backend). Opening lines say nothing about the creator's own life, results or numbers: they are things anyone could say.
nonisolated enum ThemeCatalog {
    /// One starter as it is written here.
    private struct Entry {
        var title: String
        var kind: String
        var length: ScriptLength
        var angle: String
        var openingLine: String
        var angleKind: IdeaAngle
    }

    // swiftlint:disable function_body_length
    /// The starters of a first-flight topic (six each; Wellness and Education, no longer offered, keep their three).
    static func ideas(for niche: Niche) -> [ThemeIdea] {
        let entries: [Entry] = switch niche {
        case .lifestyle: [
            Entry(
                title: String(localized: "3 things I stopped buying this year"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Share three purchases worth dropping and what changes without them."),
                openingLine: String(localized: "Here are three things worth thinking twice about before you buy them again."), angleKind: .list
            ),
            Entry(
                title: String(localized: "My Sunday reset in 60 seconds"), kind: String(localized: "Routine"), length: .minute1,
                angle: String(localized: "Walk through a simple reset that sets up the week."),
                openingLine: String(localized: "Give me sixty seconds and your Monday will feel a lot lighter."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "What a normal Tuesday really looks like"), kind: String(localized: "Vlog"), length: .minutes2,
                angle: String(localized: "Show an ordinary day honestly, without the highlight reel."),
                openingLine: String(localized: "No highlight reel today. Just an ordinary Tuesday."), angleKind: .dayInLife
            ),
            Entry(
                title: String(localized: "The 10-minute morning that actually sticks"), kind: String(localized: "Routine"), length: .minute1,
                angle: String(localized: "Show a short morning routine anyone can keep on busy days."),
                openingLine: String(localized: "If your morning routine falls apart by Wednesday, try a shorter one."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Why perfect routines fail"), kind: String(localized: "Opinion"), length: .minute1,
                angle: String(localized: "Explain why small, flexible habits beat strict schedules."),
                openingLine: String(localized: "The perfect routine is usually the first one you quit."), angleKind: .opinion
            ),
            Entry(
                title: String(localized: "One habit to try before you check your phone"), kind: String(localized: "Tip"), length: .minute1,
                angle: String(localized: "Suggest one thing to do in the first five minutes after waking up."),
                openingLine: String(localized: "Before you reach for your phone tomorrow, try this instead."), angleKind: .tool
            ),
        ]
        case .wellness: [
            Entry(
                title: String(localized: "The 5-minute habit that fixed my sleep"), kind: String(localized: "Tip"), length: .minute1,
                angle: String(localized: "Share one small evening habit that helps people fall asleep."),
                openingLine: String(localized: "If you scroll in bed until midnight, this five-minute habit is for you."), angleKind: .tool
            ),
            Entry(
                title: String(localized: "Hydration myths, busted"), kind: String(localized: "Myth-busting"), length: .minute1,
                angle: String(localized: "Bust two common hydration myths with simple, careful facts."),
                openingLine: String(localized: "You’ve probably heard you need eight glasses a day. Let’s look at that."), angleKind: .myth
            ),
            Entry(
                title: String(localized: "What I eat on a busy workday"), kind: String(localized: "Routine"), length: .minute1,
                angle: String(localized: "Walk through quick meals that keep energy steady on busy days."),
                openingLine: String(localized: "Busy days are when eating well gets hard. Let’s keep it simple."), angleKind: .dayInLife
            ),
        ]
        case .beauty: [
            Entry(
                title: String(localized: "My 5-minute everyday makeup"), kind: String(localized: "Tutorial"), length: .minute1,
                angle: String(localized: "Teach a quick everyday look, step by step."),
                openingLine: String(localized: "Five minutes, a few products, and you’re ready to go."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Products I regret buying"), kind: String(localized: "Review"), length: .minute1,
                angle: String(localized: "Review products that didn’t live up to the hype, and say why."),
                openingLine: String(localized: "Before you add these to your cart, hear me out."), angleKind: .opinion
            ),
            Entry(
                title: String(localized: "Skincare myths I believed for years"), kind: String(localized: "Myth-busting"), length: .minute1,
                angle: String(localized: "Bust the skincare myths people still repeat."),
                openingLine: String(localized: "Some skincare advice sounds right and still isn’t. Let’s sort it out."), angleKind: .myth
            ),
            Entry(
                title: String(localized: "The order to apply your skincare in"), kind: String(localized: "Tutorial"), length: .minute1,
                angle: String(localized: "Explain the order of the steps and why it matters."),
                openingLine: String(localized: "Same products, different order. Here’s the order that makes sense."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Cheap swaps for pricey beauty products"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Compare affordable picks with the expensive ones people buy."),
                openingLine: String(localized: "You don’t always need the expensive version. Let’s compare."), angleKind: .comparison
            ),
            Entry(
                title: String(localized: "The skincare question every beginner asks"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Answer the most common beginner question, simply."),
                openingLine: String(localized: "If you’re just starting with skincare, you’ve probably wondered this."), angleKind: .beginner
            ),
        ]
        case .fitness: [
            Entry(
                title: String(localized: "The only 3 exercises you need at home"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Show three simple moves that cover the whole body."),
                openingLine: String(localized: "No gym, no equipment. Just three moves to start with."), angleKind: .list
            ),
            Entry(
                title: String(localized: "What nobody tells you about starting to run"), kind: String(localized: "Storytime"), length: .minutes2,
                angle: String(localized: "Share the honest early struggles of new runners and how to get through them."),
                openingLine: String(localized: "Starting to run is harder than it looks, and that’s normal."), angleKind: .lesson
            ),
            Entry(
                title: String(localized: "Gym mistakes I made for years"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Point out common gym mistakes and the simple fix for each."),
                openingLine: String(localized: "These gym mistakes are so common that most people never notice them."), angleKind: .mistake
            ),
            Entry(
                title: String(localized: "How to warm up in 2 minutes"), kind: String(localized: "Tutorial"), length: .minute1,
                angle: String(localized: "Show a quick warm-up anyone can do before training."),
                openingLine: String(localized: "Skipping your warm-up? Here’s one that takes two minutes."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Rest days are part of the plan"), kind: String(localized: "Opinion"), length: .minute1,
                angle: String(localized: "Explain why rest helps progress instead of slowing it."),
                openingLine: String(localized: "Taking a day off isn’t lazy. It’s part of getting stronger."), angleKind: .opinion
            ),
            Entry(
                title: String(localized: "Cardio or weights first?"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Compare both orders and who each one suits."),
                openingLine: String(localized: "It’s one of the most common gym questions. Let’s settle it."), angleKind: .comparison
            ),
        ]
        case .food: [
            Entry(
                title: String(localized: "A 10-minute dinner I make every week"), kind: String(localized: "Tutorial"), length: .minute1,
                angle: String(localized: "Cook one quick dinner from start to finish."),
                openingLine: String(localized: "Ten minutes, one pan, and dinner is done."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Kitchen hacks that actually work"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Share kitchen tricks that save time without special tools."),
                openingLine: String(localized: "Forget the viral gadgets. These kitchen tricks just work."), angleKind: .list
            ),
            Entry(
                title: String(localized: "The story behind my grandma’s recipe"), kind: String(localized: "Storytime"), length: .minutes2,
                angle: String(localized: "Tell where a family recipe comes from while you cook it."),
                openingLine: String(localized: "Every family has that one recipe. Let me tell you about ours."), angleKind: .story
            ),
            Entry(
                title: String(localized: "Meal prep for people who hate meal prep"), kind: String(localized: "Tips"), length: .minute1,
                angle: String(localized: "Show the easiest way to cook once for a few days."),
                openingLine: String(localized: "If meal prep sounds like a whole Sunday gone, try this smaller version."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Pantry staples worth always having"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "List the basics that turn into many quick meals."),
                openingLine: String(localized: "With these few things in your pantry, dinner is always possible."), angleKind: .list
            ),
            Entry(
                title: String(localized: "The cooking myth that ruins your pasta"), kind: String(localized: "Myth-busting"), length: .minute1,
                angle: String(localized: "Bust one common pasta myth and show the better way."),
                openingLine: String(localized: "Adding oil to the pasta water? Let’s talk about that."), angleKind: .myth
            ),
        ]
        case .tech: [
            Entry(
                title: String(localized: "iPhone settings I change on day one"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Walk through a few settings worth changing on a new phone."),
                openingLine: String(localized: "New phone? Change these settings before anything else."), angleKind: .list
            ),
            Entry(
                title: String(localized: "Is it worth upgrading this year?"), kind: String(localized: "Opinion"), length: .minutes2,
                angle: String(localized: "Help viewers decide whether to upgrade or wait."),
                openingLine: String(localized: "Before you upgrade, ask yourself one simple question."), angleKind: .opinion
            ),
            Entry(
                title: String(localized: "Apps that replaced my notebook"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Show apps that keep notes, lists and plans in one place."),
                openingLine: String(localized: "If your notes are scattered everywhere, these apps can help."), angleKind: .tool
            ),
            Entry(
                title: String(localized: "AI tools for everyday tasks"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Show simple ways AI can help with ordinary chores."),
                openingLine: String(localized: "You don’t need to be technical to get help from AI."), angleKind: .tool
            ),
            Entry(
                title: String(localized: "Why your phone battery drains so fast"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Explain the usual causes and what actually helps."),
                openingLine: String(localized: "If your battery is gone by lunch, here’s what’s likely going on."), angleKind: .fact
            ),
            Entry(
                title: String(localized: "Tech myths people still believe"), kind: String(localized: "Myth-busting"), length: .minute1,
                angle: String(localized: "Bust a few tech myths with clear explanations."),
                openingLine: String(localized: "Closing all your apps to save battery? Let’s talk about that."), angleKind: .myth
            ),
        ]
        case .finance: [
            Entry(
                title: String(localized: "Compound interest, explained simply"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Explain compound interest with one everyday example."),
                openingLine: String(localized: "Compound interest sounds complicated. It’s simpler than you think."), angleKind: .fact
            ),
            Entry(
                title: String(localized: "How I budget without spreadsheets"), kind: String(localized: "Tutorial"), length: .minute1,
                angle: String(localized: "Show a simple budgeting method that needs no spreadsheet."),
                openingLine: String(localized: "If spreadsheets make you want to quit budgeting, try this instead."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Money mistakes I made in my 20s"), kind: String(localized: "Storytime"), length: .minutes2,
                angle: String(localized: "Point out common money mistakes in your twenties and how to avoid them."),
                openingLine: String(localized: "Some money mistakes are easy to make in your twenties. Let’s avoid them."), angleKind: .mistake
            ),
            Entry(
                title: String(localized: "Why saving feels harder than spending"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Explain one small habit that makes saving easier."),
                openingLine: String(localized: "Saving isn’t just about willpower. It’s about what you make automatic."), angleKind: .fact
            ),
            Entry(
                title: String(localized: "The emergency fund, explained"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Explain what an emergency fund is for and how to start one."),
                openingLine: String(localized: "An emergency fund is the most boring money tool, and maybe the most useful."), angleKind: .beginner
            ),
            Entry(
                title: String(localized: "Needs vs wants: a simple test"), kind: String(localized: "Tips"), length: .minute1,
                angle: String(localized: "Give viewers a quick test to use before they buy something."),
                openingLine: String(localized: "Before your next purchase, ask yourself this one question."), angleKind: .tool
            ),
        ]
        case .fashion: [
            Entry(
                title: String(localized: "3 outfits from one pair of jeans"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Style one pair of jeans three different ways."),
                openingLine: String(localized: "One pair of jeans, three completely different looks."), angleKind: .list
            ),
            Entry(
                title: String(localized: "How I built a capsule wardrobe"), kind: String(localized: "Tutorial"), length: .minutes2,
                angle: String(localized: "Explain how to start a capsule wardrobe, step by step."),
                openingLine: String(localized: "A smaller wardrobe can make getting dressed so much easier."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Trends I’m skipping this season"), kind: String(localized: "Opinion"), length: .minute1,
                angle: String(localized: "Say which trends are worth skipping, and why."),
                openingLine: String(localized: "Not every trend is worth your money. Here’s what I’d skip."), angleKind: .opinion
            ),
            Entry(
                title: String(localized: "How to find your style"), kind: String(localized: "Tips"), length: .minute1,
                angle: String(localized: "Give simple steps to figure out what you like to wear."),
                openingLine: String(localized: "If your closet is full and you have nothing to wear, start here."), angleKind: .beginner
            ),
            Entry(
                title: String(localized: "Styling mistakes that are easy to fix"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Point out small styling mistakes and the quick fix for each."),
                openingLine: String(localized: "Small changes make a big difference. Let’s fix a few common ones."), angleKind: .mistake
            ),
            Entry(
                title: String(localized: "Basics worth spending more on"), kind: String(localized: "Opinion"), length: .minute1,
                angle: String(localized: "Compare where quality matters and where cheap is fine."),
                openingLine: String(localized: "Some basics are worth spending more on, and some really aren’t."), angleKind: .comparison
            ),
        ]
        case .travel: [
            Entry(
                title: String(localized: "How I plan a trip on a tight budget"), kind: String(localized: "Tutorial"), length: .minutes2,
                angle: String(localized: "Walk through planning a trip on a small budget, step by step."),
                openingLine: String(localized: "A great trip doesn’t need a big budget. It needs a plan."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Hidden gems most tourists miss"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Show how to find the quieter spots most visitors skip."),
                openingLine: String(localized: "The best places are often one street away from the crowds."), angleKind: .list
            ),
            Entry(
                title: String(localized: "The travel mistake that cost me a day"), kind: String(localized: "Storytime"), length: .minutes2,
                angle: String(localized: "Warn viewers about one common travel mistake and how to avoid it."),
                openingLine: String(localized: "One small travel mistake can cost you a whole day. Here’s how to avoid it."), angleKind: .mistake
            ),
            Entry(
                title: String(localized: "Packing light for a week"), kind: String(localized: "Tutorial"), length: .minute1,
                angle: String(localized: "Show how to fit a week into one small bag."),
                openingLine: String(localized: "A week, one small bag, and nothing you’ll miss."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Cheap flights: what really works"), kind: String(localized: "Myth-busting"), length: .minute1,
                angle: String(localized: "Separate the booking tips that work from the myths."),
                openingLine: String(localized: "There are a lot of flight myths out there. Let’s sort them out."), angleKind: .myth
            ),
            Entry(
                title: String(localized: "How to eat well abroad for less"), kind: String(localized: "Tips"), length: .minute1,
                angle: String(localized: "Share simple ways to eat well on a budget while traveling."),
                openingLine: String(localized: "Eating out every meal adds up fast. Here’s how to keep it affordable."), angleKind: .list
            ),
        ]
        case .productivity: [
            Entry(
                title: String(localized: "The email rule that saves me an hour a day"), kind: String(localized: "Tip"), length: .minute1,
                angle: String(localized: "Share one simple email rule and how to start using it."),
                openingLine: String(localized: "If your inbox runs your day, try this one rule."), angleKind: .tool
            ),
            Entry(
                title: String(localized: "Why to-do lists fail, and what works"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Explain why most lists fail and offer a better approach."),
                openingLine: String(localized: "Your to-do list isn’t the problem. The way it’s built might be."), angleKind: .opinion
            ),
            Entry(
                title: String(localized: "How I say no at work"), kind: String(localized: "Tips"), length: .minute1,
                angle: String(localized: "Give polite ways to say no without hurting relationships."),
                openingLine: String(localized: "Saying no at work is a skill, and you can learn it."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "The 2-minute rule, explained"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Explain the rule, and when it helps and when it doesn’t."),
                openingLine: String(localized: "If a task takes less than two minutes, there’s a simple rule for it."), angleKind: .fact
            ),
            Entry(
                title: String(localized: "How to plan your week in 15 minutes"), kind: String(localized: "Tutorial"), length: .minute1,
                angle: String(localized: "Show a quick weekly planning routine, step by step."),
                openingLine: String(localized: "Fifteen minutes on Sunday can make the whole week calmer."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Multitasking myths"), kind: String(localized: "Myth-busting"), length: .minute1,
                angle: String(localized: "Explain why doing one thing at a time often works better."),
                openingLine: String(localized: "Doing three things at once feels productive. Let’s look at that."), angleKind: .myth
            ),
        ]
        case .parenting: [
            Entry(
                title: String(localized: "A calm bedtime routine that works"), kind: String(localized: "Routine"), length: .minute1,
                angle: String(localized: "Walk through a simple bedtime routine, step by step."),
                openingLine: String(localized: "If bedtime feels like a battle, a calmer routine can help."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Things I wish I knew as a new parent"), kind: String(localized: "List"), length: .minute1,
                angle: String(localized: "Share practical tips for the first months with a baby."),
                openingLine: String(localized: "Nobody hands you a manual. Here are a few things worth knowing."), angleKind: .list
            ),
            Entry(
                title: String(localized: "Tantrums without losing my cool"), kind: String(localized: "Tips"), length: .minute1,
                angle: String(localized: "Give a few calm ways to respond in the middle of a tantrum."),
                openingLine: String(localized: "When a tantrum starts, the first thing to do is breathe."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Screen time without the guilt"), kind: String(localized: "Opinion"), length: .minute1,
                angle: String(localized: "Share a balanced take on kids and screens."),
                openingLine: String(localized: "Screen time doesn’t have to be all or nothing."), angleKind: .opinion
            ),
            Entry(
                title: String(localized: "Getting kids to help at home"), kind: String(localized: "Tips"), length: .minute1,
                angle: String(localized: "Suggest simple chores by age and how to make them stick."),
                openingLine: String(localized: "Kids can help more than we think. Here’s how to start."), angleKind: .list
            ),
            Entry(
                title: String(localized: "Parenting advice to ignore"), kind: String(localized: "Myth-busting"), length: .minute1,
                angle: String(localized: "Bust a few popular parenting tips that don’t fit every family."),
                openingLine: String(localized: "Not every piece of parenting advice fits your family, and that’s okay."), angleKind: .myth
            ),
        ]
        case .education: [
            Entry(
                title: String(localized: "A history fact that sounds fake"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Tell one surprising, true moment from history."),
                openingLine: String(localized: "This sounds made up, but it really happened."), angleKind: .fact
            ),
            Entry(
                title: String(localized: "How to learn anything faster"), kind: String(localized: "Tips"), length: .minute1,
                angle: String(localized: "Share study techniques that help ideas stick."),
                openingLine: String(localized: "If you forget what you studied by the next day, try this."), angleKind: .tutorial
            ),
            Entry(
                title: String(localized: "Where the word “OK” comes from"), kind: String(localized: "Explainer"), length: .minute1,
                angle: String(localized: "Explain the surprising origin of an everyday word."),
                openingLine: String(localized: "You probably say it every day. Do you know where it comes from?"), angleKind: .fact
            ),
        ]
        }
        return entries.map { entry in
            var idea = ThemeIdea(title: entry.title, kind: entry.kind, length: entry.length, niche: niche)
            idea.brief = IdeaBrief(
                subject: entry.title, angle: entry.angle, openingLine: entry.openingLine, language: interfaceLanguage,
                angleKind: entry.angleKind.rawValue, topicKey: niche.rawValue
            )
            return idea
        }
    }
    // swiftlint:enable function_body_length

    /// Starters for a topic Cue has none of its own for (one only My Cue Voice offers, or one the creator typed): briefs made from the topic's
    /// name and its subtopics, one for each way of looking at it here. Better than starters about something they don't make.
    static func ideas(for topic: IdeaTopic) -> [ThemeIdea] {
        if let niche = topic.niche { return ideas(for: niche) }
        // The topic itself, then each of its subtopics in turn: "Languages", "Italian", "Languages"…
        let subjects = [nil] + topic.subtopics.map(Optional.some)
        return templates.enumerated().map { index, template in
            let subtopic = subjects[index % subjects.count]
            let name = subtopic ?? topic.label
            let parts = template(name)
            var idea = ThemeIdea(title: parts.title, kind: parts.kind, length: parts.length, niche: .lifestyle, topic: topic.label)
            idea.brief = IdeaBrief(
                subject: parts.title, angle: parts.angle, openingLine: parts.openingLine, subtopic: subtopic, language: interfaceLanguage,
                angleKind: parts.angleKind.rawValue, topicKey: topic.label
            )
            return idea
        }
    }

    /// Starters for a creator who has chosen no topic yet: everyday ones anyone could film (daily life, productivity, food), in turn.
    static var general: [ThemeIdea] {
        let lists = [Niche.lifestyle, .productivity, .food].map(ideas(for:))
        let longest = lists.map(\.count).max() ?? 0
        return (0..<longest).flatMap { index in lists.compactMap { index < $0.count ? $0[index] : nil } }
    }

    /// The starters of a set of topics, the first of each topic, then the second of each…: what Find inspiration shows for "All my topics" while
    /// the model's ideas are on their way, and what it shows without Apple Intelligence.
    static func ideas(for topics: [IdeaTopic]) -> [ThemeIdea] {
        guard !topics.isEmpty else { return general }
        let lists = topics.map(ideas(for:))
        let longest = lists.map(\.count).max() ?? 0
        return (0..<longest).flatMap { index in lists.compactMap { index < $0.count ? $0[index] : nil } }
    }

    private typealias Template = (String) -> Entry

    /// The ways of looking at a topic a starter is made with, `name` being the topic or a subtopic as the creator wrote it.
    private static var templates: [Template] { [
        { name in Entry(
            title: String(localized: "\(name): the mistake beginners make"), kind: String(localized: "Tips"), length: .minute1,
            angle: String(localized: "Point out one common beginner mistake and how to avoid it."),
            openingLine: String(localized: "If you’re just getting into \(name), watch out for this one."), angleKind: .mistake
        ) },
        { name in Entry(
            title: String(localized: "\(name) myths worth busting"), kind: String(localized: "Myth-busting"), length: .minute1,
            angle: String(localized: "Bust a myth people still believe, with a clear explanation."),
            openingLine: String(localized: "There’s one thing about \(name) that people keep getting wrong."), angleKind: .myth
        ) },
        { name in Entry(
            title: String(localized: "3 simple tips for \(name)"), kind: String(localized: "List"), length: .minute1,
            angle: String(localized: "Share three practical tips someone could try this week."),
            openingLine: String(localized: "Three small things you can try with \(name) this week."), angleKind: .list
        ) },
        { name in Entry(
            title: String(localized: "Where to start with \(name)"), kind: String(localized: "Explainer"), length: .minute1,
            angle: String(localized: "Answer the question every beginner asks, simply."),
            openingLine: String(localized: "If you’ve ever wondered where to start with \(name), this is for you."), angleKind: .beginner
        ) },
        { name in Entry(
            title: String(localized: "What nobody tells you about \(name)"), kind: String(localized: "Storytime"), length: .minute1,
            angle: String(localized: "Share the honest side most people only learn later."),
            openingLine: String(localized: "Here’s what nobody tells you when you start with \(name)."), angleKind: .lesson
        ) },
        { name in Entry(
            title: String(localized: "My honest take on \(name)"), kind: String(localized: "Opinion"), length: .minute1,
            angle: String(localized: "Give a clear opinion and the reason behind it."),
            openingLine: String(localized: "Let me tell you what I really think about \(name)."), angleKind: .opinion
        ) },
        { name in Entry(
            title: String(localized: "\(name) in one minute"), kind: String(localized: "Tutorial"), length: .minute1,
            angle: String(localized: "Explain one useful how-to in under a minute."),
            openingLine: String(localized: "Give me one minute and I’ll show you something useful about \(name)."), angleKind: .tutorial
        ) },
    ] }

    /// The language the starters are read in (the app's own localization), as a minimal identifier.
    private static var interfaceLanguage: String? {
        Bundle.main.preferredLocalizations.first.map { Locale.Language(identifier: $0).minimalIdentifier }
    }
}
