//
//  SoundEffect.swift
//  Cue Studio
//

import Foundation

/// The sound effects Cue offers for creator videos: most are recordings of real objects and instruments from CC0 libraries, put
/// together and leveled offline (`tools/music/`) and shipped in the app; a few tonal ones are made on the device
/// (`SoundEffectSynth`). Every one is free to use in any video, with no credit (`SoundEffectFiles` says where each file is).
/// Declared in display order, group by group (`SoundEffectCategory`); the raw values are what an edit stores, so the order can
/// change freely.
nonisolated enum SoundEffect: String, Codable, CaseIterable, Identifiable, Sendable {
    // Transitions
    case whoosh, swish, riser, drop, glitch, pageTurn, dream, footsteps
    // Text & graphics
    case pop, click, doubleClick, bloop, typing, tick
    // Reactions
    case ding, buzzer, tada, fanfare, coin, cashRegister, referee
    // Comedy
    case rimshot, recordScratch, boing, sadTrombone, slap, clang, slideWhistle, cartoonRun, sneaky
    // Big moments
    case boom, hit, sparkle, drumRoll, heartbeat, sting, gong
    // Alerts & time
    case ping, shutter, countdown, tickTock, censor

    var id: String { rawValue }

    /// The effects of a group, in display order.
    static func effects(in category: SoundEffectCategory) -> [SoundEffect] {
        allCases.filter { $0.category == category }
    }

    var category: SoundEffectCategory {
        switch self {
        case .whoosh, .swish, .riser, .drop, .glitch, .pageTurn, .dream, .footsteps: .transitions
        case .pop, .click, .doubleClick, .bloop, .typing, .tick: .textAndGraphics
        case .ding, .buzzer, .tada, .fanfare, .coin, .cashRegister, .referee: .reactions
        case .rimshot, .recordScratch, .boing, .sadTrombone, .slap, .clang, .slideWhistle, .cartoonRun, .sneaky: .comedy
        case .boom, .hit, .sparkle, .drumRoll, .heartbeat, .sting, .gong: .bigMoments
        case .ping, .shutter, .countdown, .tickTock, .censor: .alertsAndTime
        }
    }

    var label: String {
        switch self {
        case .whoosh: String(localized: "Whoosh")
        case .swish: String(localized: "Swish")
        case .riser: String(localized: "Riser")
        case .drop: String(localized: "Bass drop")
        case .glitch: String(localized: "Glitch")
        case .pageTurn: String(localized: "Page turn")
        case .dream: String(localized: "Dream harp")
        case .footsteps: String(localized: "Footsteps")
        case .pop: String(localized: "Pop", comment: "Sound effect")
        case .click: String(localized: "Click")
        case .doubleClick: String(localized: "Double click")
        case .bloop: String(localized: "Bloop")
        case .typing: String(localized: "Typing")
        case .tick: String(localized: "Tick")
        case .ding: String(localized: "Ding")
        case .buzzer: String(localized: "Wrong")
        case .tada: String(localized: "Ta-da")
        case .fanfare: String(localized: "Fanfare")
        case .coin: String(localized: "Coin")
        case .cashRegister: String(localized: "Cash register")
        case .referee: String(localized: "Referee whistle")
        case .rimshot: String(localized: "Ba-dum-tss")
        case .recordScratch: String(localized: "Record scratch")
        case .boing: String(localized: "Boing")
        case .sadTrombone: String(localized: "Sad trombone")
        case .slap: String(localized: "Slap")
        case .clang: String(localized: "Clang")
        case .slideWhistle: String(localized: "Slide whistle")
        case .cartoonRun: String(localized: "Cartoon run")
        case .sneaky: String(localized: "Sneaky")
        case .boom: String(localized: "Boom")
        case .hit: String(localized: "Hit")
        case .sparkle: String(localized: "Sparkle")
        case .drumRoll: String(localized: "Drum roll")
        case .heartbeat: String(localized: "Heartbeat")
        case .sting: String(localized: "Dramatic sting")
        case .gong: String(localized: "Gong")
        case .ping: String(localized: "Ping")
        case .shutter: String(localized: "Shutter")
        case .countdown: String(localized: "Countdown")
        case .tickTock: String(localized: "Tick-tock")
        case .censor: String(localized: "Bleep")
        }
    }

    /// What it's for, in a word or two.
    var use: String {
        switch self {
        case .whoosh: String(localized: "Transitions")
        case .swish: String(localized: "Quick cuts")
        case .riser: String(localized: "Build-up")
        case .drop: String(localized: "Mood change")
        case .glitch: String(localized: "Digital cut")
        case .pageTurn: String(localized: "Next chapter")
        case .dream: String(localized: "Flashback")
        case .footsteps: String(localized: "Walking in")
        case .pop: String(localized: "Text appears")
        case .click: String(localized: "Taps, steps")
        case .doubleClick: String(localized: "Screen demos")
        case .bloop: String(localized: "Icons, stickers")
        case .typing: String(localized: "Words typed")
        case .tick: String(localized: "List items")
        case .ding: String(localized: "Right answer")
        case .buzzer: String(localized: "Mistake")
        case .tada: String(localized: "Success")
        case .fanfare: String(localized: "Victory")
        case .coin: String(localized: "Reward")
        case .cashRegister: String(localized: "Sale, money")
        case .referee: String(localized: "Foul, time out")
        case .rimshot: String(localized: "Punchline")
        case .recordScratch: String(localized: "Wait, what?")
        case .boing: String(localized: "Funny moment")
        case .sadTrombone: String(localized: "Fail")
        case .slap: String(localized: "Comic hit")
        case .clang: String(localized: "Clumsy moment")
        case .slideWhistle: String(localized: "Falling, silly")
        case .cartoonRun: String(localized: "Running off")
        case .sneaky: String(localized: "Tiptoeing")
        case .boom: String(localized: "Big moment")
        case .hit: String(localized: "Key point")
        case .sparkle: String(localized: "Reveal")
        case .drumRoll: String(localized: "Suspense")
        case .heartbeat: String(localized: "Tension")
        case .sting: String(localized: "Plot twist")
        case .gong: String(localized: "Big announcement")
        case .ping: String(localized: "Notification")
        case .shutter: String(localized: "Photo")
        case .countdown: String(localized: "Get ready")
        case .tickTock: String(localized: "Time passing")
        case .censor: String(localized: "Censor a word")
        }
    }

    var systemImage: String {
        switch self {
        case .whoosh: "wind"
        case .swish: "hare"
        case .riser: "arrow.up.right"
        case .drop: "arrow.down.right"
        case .glitch: "bolt.horizontal"
        case .pageTurn: "book.pages"
        case .dream: "cloud"
        case .footsteps: "shoeprints.fill"
        case .pop: "circle.dotted"
        case .click: "cursorarrow.click"
        case .doubleClick: "cursorarrow.click.2"
        case .bloop: "drop"
        case .typing: "keyboard"
        case .tick: "list.bullet"
        case .ding: "bell"
        case .buzzer: "xmark.octagon"
        case .tada: "party.popper"
        case .fanfare: "trophy"
        case .coin: "star.circle"
        case .cashRegister: "dollarsign.circle"
        case .referee: "flag.fill"
        case .rimshot: "face.smiling.inverse"
        case .recordScratch: "opticaldisc"
        case .boing: "arrow.up.and.down"
        case .sadTrombone: "hand.thumbsdown"
        case .slap: "hand.raised"
        case .clang: "hammer"
        case .slideWhistle: "figure.fall"
        case .cartoonRun: "figure.run"
        case .sneaky: "eyes"
        case .boom: "burst"
        case .hit: "bolt"
        case .sparkle: "sparkles"
        case .drumRoll: "music.quarternote.3"
        case .heartbeat: "heart"
        case .sting: "exclamationmark.2"
        case .gong: "circle.circle"
        case .ping: "bell.badge"
        case .shutter: "camera.shutter.button"
        case .countdown: "timer"
        case .tickTock: "clock"
        case .censor: "nosign"
        }
    }

    /// Bumped when a synthesized sound's recipe or level changes, so files made with the old one aren't reused (2: every effect
    /// set to the same loudness, not the same peak). A recording changes with the app; an edit keeps the file it linked.
    static let version = 2
}
