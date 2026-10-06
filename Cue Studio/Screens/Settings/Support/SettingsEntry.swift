//
//  SettingsEntry.swift
//  Cue Studio
//

import Foundation

/// Every row Settings can find: its words (for the search) and where it lives ("Prompter › Rigs"). The pages draw their rows
/// from the same entries (`SettingsEntryRow`), so a search result is the row itself, not a link to it.
nonisolated enum SettingsEntry: String, CaseIterable, Identifiable, Sendable {
    // The root
    case recording, prompter, remote, myCueVoice, personalize
    case languageRegion, privacy
    case cuePro, restorePurchases
    case privacyPolicy, termsOfUse, acknowledgements, version
    // Recording
    case startsWith, resolution, frameRate, defaultFormat, microphone, countdown, grid
    // Prompter
    case followVoice, speed, countdownBeforePlay, aiCoach
    case textSize, font, lineSpacing, alignment, textColor
    case showReadingLine, readingLinePosition, resetReadingLine
    case windowHeight, windowWidth, sideMargins
    case backgroundOpacity, cameraBlur, socialSafeZone
    case studioBackground
    case mirrorText, flipVertically
    // Remote
    case connectDevice, enterCode, scanCode
    // Personalize
    case appIcon, topics, autoTag
    case starrySky, celebrations, haptics
    // Language & Region
    case appLanguage, voiceFollowingLanguage, scriptLanguage
    // Privacy & AI data
    case onDeviceAI, helpImprove, permissions, deleteData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recording: String(localized: "Recording")
        case .prompter: String(localized: "Prompter")
        case .remote: String(localized: "Remote")
        case .myCueVoice: String(localized: "My Cue Voice")
        case .personalize: String(localized: "Personalize")
        case .languageRegion: String(localized: "Language & Region")
        case .privacy: String(localized: "Privacy & AI data")
        case .cuePro: String(localized: "Cue Pro")
        case .restorePurchases: String(localized: "Restore purchases")
        case .privacyPolicy: String(localized: "Privacy policy")
        case .termsOfUse: String(localized: "Terms of use")
        case .acknowledgements: String(localized: "Acknowledgements")
        case .version: String(localized: "Version")
        case .startsWith: String(localized: "Starts with")
        case .resolution: String(localized: "Resolution")
        case .frameRate: String(localized: "Frame rate")
        case .defaultFormat: String(localized: "Default format")
        case .microphone: String(localized: "Input")
        case .countdown: String(localized: "Countdown")
        case .countdownBeforePlay: String(localized: "Countdown before play")
        case .grid: String(localized: "Grid")
        case .followVoice: String(localized: "Follow my voice")
        case .speed: String(localized: "Speed")
        case .aiCoach: String(localized: "AI Coach")
        case .textSize: String(localized: "Text size")
        case .font: String(localized: "Font")
        case .lineSpacing: String(localized: "Line spacing")
        case .alignment: String(localized: "Alignment")
        case .textColor: String(localized: "Text color")
        case .showReadingLine: String(localized: "Show reading line")
        case .readingLinePosition: String(localized: "Position")
        case .resetReadingLine: String(localized: "Reset to recommended")
        case .windowHeight: String(localized: "Height")
        case .windowWidth: String(localized: "Width")
        case .sideMargins: String(localized: "Side margins")
        case .backgroundOpacity: String(localized: "Background opacity")
        case .cameraBlur: String(localized: "Camera blur")
        case .socialSafeZone: String(localized: "Social safe zone")
        case .studioBackground: String(localized: "Background color")
        case .mirrorText: String(localized: "Mirror text")
        case .flipVertically: String(localized: "Flip vertically")
        case .connectDevice: String(localized: "Connect a device")
        case .enterCode: String(localized: "Enter a code")
        case .scanCode: String(localized: "Scan the code")
        case .appIcon: String(localized: "App icon")
        case .topics: String(localized: "Your topics")
        case .autoTag: String(localized: "Tag new scripts automatically")
        case .starrySky: String(localized: "Starry sky")
        case .celebrations: String(localized: "Celebrations")
        case .haptics: String(localized: "Haptics")
        case .appLanguage: String(localized: "App language")
        case .voiceFollowingLanguage: String(localized: "Voice following")
        case .scriptLanguage: String(localized: "Script language")
        case .onDeviceAI: String(localized: "On-device AI")
        case .helpImprove: String(localized: "Help improve Cue")
        case .permissions: String(localized: "Permissions")
        case .deleteData: String(localized: "Delete my Cue data")
        }
    }

    /// The second line some rows have under the title.
    var detail: String? {
        switch self {
        case .grid: String(localized: "Rule of thirds over the camera")
        case .windowWidth: String(localized: "Narrow means less eye movement")
        case .followVoice: String(localized: "The text moves when you speak")
        case .speed: String(localized: "Used when Cue isn't following you")
        case .aiCoach: String(localized: "Cues like PAUSE or SMILE in the text")
        case .mirrorText: String(localized: "For beam-splitter glass")
        case .flipVertically: String(localized: "For rigs that reflect from below")
        case .appIcon: String(localized: "Aurora and First Light unlock with milestones")
        case .topics: String(localized: "Edit them in My Cue Voice")
        case .autoTag: String(localized: "Cue picks the topic on this iPhone")
        case .onDeviceAI: String(localized: "Scripts and My Cue Voice stay on this iPhone")
        case .helpImprove: String(localized: "Anonymous usage, never videos or scripts")
        default: nil
        }
    }

    /// Where the row lives: the section of its page, or the section of the root for the rows that open a page.
    var path: String {
        switch self {
        case .recording, .prompter, .remote: String(localized: "Create")
        case .myCueVoice, .personalize: String(localized: "Your Cue")
        case .languageRegion, .privacy: String(localized: "General")
        case .cuePro, .restorePurchases: String(localized: "Pro")
        case .privacyPolicy, .termsOfUse, .acknowledgements, .version: String(localized: "About")
        case .startsWith: Self.path(.recording, String(localized: "Camera"))
        case .resolution, .frameRate: Self.path(.recording, String(localized: "Quality"))
        case .defaultFormat: Self.path(.recording, String(localized: "Default format"))
        case .microphone: Self.path(.recording, String(localized: "Microphone"))
        case .countdown, .grid: Self.path(.recording, String(localized: "While recording"))
        case .followVoice, .speed, .countdownBeforePlay, .aiCoach: Self.path(.prompter, String(localized: "Reading"))
        case .textSize, .font, .lineSpacing, .alignment, .textColor: Self.path(.prompter, String(localized: "Text"))
        case .showReadingLine, .readingLinePosition, .resetReadingLine: Self.path(.prompter, String(localized: "Reading line"))
        case .windowHeight, .windowWidth, .sideMargins: Self.path(.prompter, String(localized: "Text window"))
        case .backgroundOpacity, .cameraBlur, .socialSafeZone: Self.path(.prompter, String(localized: "Over the camera"))
        case .studioBackground: Self.path(.prompter, String(localized: "Studio"))
        case .mirrorText, .flipVertically: Self.path(.prompter, String(localized: "Rigs"))
        case .connectDevice: Self.path(.remote, String(localized: "Connect a device"))
        case .enterCode, .scanCode: Self.path(.remote, String(localized: "Use this iPhone as a remote"))
        case .appIcon: Self.path(.personalize, String(localized: "App icon"))
        case .topics, .autoTag: Self.path(.personalize, String(localized: "Topics & colors"))
        case .starrySky, .celebrations, .haptics: Self.path(.personalize, String(localized: "Motion"))
        case .appLanguage, .voiceFollowingLanguage, .scriptLanguage: SettingsEntry.languageRegion.title
        case .onDeviceAI, .helpImprove, .permissions, .deleteData: SettingsEntry.privacy.title
        }
    }

    /// Other words that should find the row. English only: the row's own words are searched in the language shown.
    var keywords: [String] {
        switch self {
        case .recording: ["camera", "video", "quality"]
        case .prompter: ["teleprompter", "text", "reading"]
        case .remote: ["control", "ipad", "watch", "pair"]
        case .myCueVoice: ["voice", "style", "tone"]
        case .personalize: ["icon", "sky", "haptics"]
        case .languageRegion: ["language", "locale", "translate"]
        case .privacy: ["data", "ai", "delete", "permissions"]
        case .cuePro: ["pro", "subscription", "plan", "upgrade", "trial"]
        case .restorePurchases: ["purchase", "subscription"]
        case .startsWith: ["camera", "front", "back", "selfie", "lens"]
        case .resolution: ["quality", "720p", "1080p", "4k", "hd"]
        case .frameRate: ["fps", "quality", "24", "30", "60"]
        case .defaultFormat: ["aspect", "ratio", "9:16", "4:5", "1:1", "16:9", "portrait", "landscape", "square"]
        case .microphone: ["mic", "microphone", "audio", "airpods", "input"]
        case .countdown, .countdownBeforePlay: ["timer", "delay", "3", "5", "10"]
        case .grid: ["lines", "thirds", "framing"]
        case .followVoice: ["voice following", "speech", "scroll"]
        case .speed: ["pace", "wpm", "words", "scroll", "slow", "fast"]
        case .aiCoach: ["cues", "pause", "smile", "coach"]
        case .textSize: ["size", "small", "medium", "large", "bigger"]
        case .font: ["typeface", "lexend", "atkinson", "serif", "rounded", "new york"]
        case .lineSpacing: ["leading", "tight", "airy", "gap"]
        case .alignment: ["left", "center", "right"]
        case .textColor: ["colour", "white", "yellow", "cream"]
        case .showReadingLine, .readingLinePosition, .resetReadingLine: ["guide", "line", "eye", "lens"]
        case .windowHeight, .windowWidth, .sideMargins: ["box", "window", "size", "margin", "selfie"]
        case .backgroundOpacity: ["dark", "dim", "panel", "selfie"]
        case .cameraBlur: ["blur", "selfie", "background"]
        case .socialSafeZone: ["tiktok", "reels", "shorts", "guide", "buttons", "caption"]
        case .studioBackground: ["black", "graphite", "navy", "color", "colour"]
        case .mirrorText: ["flip", "reverse", "beam splitter", "glass", "rig"]
        case .flipVertically: ["upside down", "reflect", "rig", "mirror"]
        case .connectDevice: ["pair", "qr", "remote"]
        case .enterCode, .scanCode: ["pair", "join", "qr", "remote"]
        case .appIcon: ["deep space", "first light", "icon"]
        case .topics: ["niche", "colors", "worlds"]
        case .autoTag: ["topic", "tag", "automatic"]
        case .starrySky: ["stars", "motion", "serene", "adrift", "interstellar", "calm", "lively", "galactic", "spaceship", "astronaut", "space", "background"]
        case .celebrations: ["confetti", "milestone", "motion"]
        case .haptics: ["vibration", "feedback", "taps"]
        case .appLanguage: ["interface", "english", "português"]
        case .voiceFollowingLanguage: ["speech", "listen", "recognition"]
        case .scriptLanguage: ["write", "new scripts", "auto-detect"]
        case .onDeviceAI: ["apple intelligence", "private", "ai"]
        case .helpImprove: ["analytics", "usage", "anonymous"]
        case .permissions: ["camera", "microphone", "speech", "photos", "access"]
        case .deleteData: ["erase", "reset", "remove", "scripts", "takes"]
        case .privacyPolicy: ["legal"]
        case .termsOfUse: ["legal", "eula"]
        case .acknowledgements: ["fonts", "licenses", "credits", "legal"]
        case .version: ["build"]
        }
    }

    private static func path(_ page: SettingsEntry, _ section: String) -> String {
        "\(page.title) › \(section)"
    }
}
