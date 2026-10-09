//
//  FeatureID+Copy.swift
//  Cue Studio
//

import Foundation

/// The words that introduce each tool: the notification (title and line) and the introduction in the app (the tool's name, one clear
/// benefit, and what it uses). Benefit first; the creator's choice in every line. Nothing about how anyone looks: Skin Smoothing is a
/// finish the creator may choose, starting at zero.
nonisolated extension FeatureID {
    var notificationTitle: String {
        switch self {
        case .myCueVoice: String(localized: "Want scripts that sound more like you?")
        case .importWriting: String(localized: "Show Cue something you wrote")
        case .ideas: String(localized: "Not sure what to record?")
        case .logbook: String(localized: "Save an idea before it disappears")
        case .voiceFollowing: String(localized: "Read at your own pace")
        case .cleanUp: String(localized: "Review pauses and repetitions")
        case .autoCaptions: String(localized: "Captions for watching without sound")
        case .captionTranslation: String(localized: "Captions in another language")
        case .studioVoice: String(localized: "Explore a clearer sound for your voice")
        case .skinSmoothing: String(localized: "Try a subtle finish")
        case .backgrounds: String(localized: "Want a different setting?")
        case .covers: String(localized: "Choose the first image of your video")
        case .layers: String(localized: "Show examples while you speak")
        case .voiceOver: String(localized: "Add a voice-over")
        case .remoteControl: String(localized: "Record from a distance")
        case .safeZones: String(localized: "Keep your words clear of the buttons")
        case .yourUniverse: String(localized: "See how your videos are shaping your universe")
        }
    }

    var notificationBody: String {
        switch self {
        case .myCueVoice: String(localized: "Answer four quick questions and Cue writes in your voice.")
        case .importWriting: String(localized: "Refine your writing style from texts you wrote. It stays on this iPhone.")
        case .ideas: String(localized: "Explore ideas for your topics.")
        case .logbook: String(localized: "Catch it in the Logbook now. Develop it later.")
        case .voiceFollowing: String(localized: "The teleprompter can follow your voice.")
        case .cleanUp: String(localized: "Without finding every section by hand. You choose what stays.")
        case .autoCaptions: String(localized: "Give your audience a way to follow your video without sound.")
        case .captionTranslation: String(localized: "Try presenting your video with captions in another language.")
        case .studioVoice: String(localized: "Studio Voice works on your recording. You hear it before you keep it.")
        case .skinSmoothing: String(localized: "A finish you can add in Adjust. You choose the intensity, from zero.")
        case .backgrounds: String(localized: "Explore your editor’s backgrounds.")
        case .covers: String(localized: "Pick the cover that introduces your video.")
        case .layers: String(localized: "Add images to your video while you talk about them.")
        case .voiceOver: String(localized: "Narrate over your edit. Cue explains it before you record.")
        case .remoteControl: String(localized: "Control the teleprompter from your other iPhone or iPad.")
        case .safeZones: String(localized: "Check that your captions stay clear of the network’s buttons.")
        case .yourUniverse: String(localized: "Every video you share becomes a star in it.")
        }
    }

    /// The introduction's title: the tool's own name.
    var name: String {
        switch self {
        case .myCueVoice: String(localized: "My Cue Voice")
        case .importWriting: String(localized: "Import my writing")
        case .ideas: String(localized: "Ideas for your topics")
        case .logbook: String(localized: "Logbook")
        case .voiceFollowing: String(localized: "Voice Following")
        case .cleanUp: String(localized: "Clean Up")
        case .autoCaptions: String(localized: "Auto captions")
        case .captionTranslation: String(localized: "Translated captions")
        case .studioVoice: String(localized: "Studio Voice")
        case .skinSmoothing: String(localized: "Skin Smoothing")
        case .backgrounds: String(localized: "Background")
        case .covers: String(localized: "Cover")
        case .layers: String(localized: "Photo or video")
        case .voiceOver: String(localized: "Voice-over")
        case .remoteControl: String(localized: "Remote Control")
        case .safeZones: String(localized: "Social safe zone")
        case .yourUniverse: String(localized: "Your universe")
        }
    }

    /// The one benefit the introduction promises.
    var benefit: String {
        switch self {
        case .myCueVoice: String(localized: "Scripts that sound more like you. Four questions, and you can change any answer.")
        case .importWriting: String(localized: "Show Cue something you wrote, and it learns how you put things.")
        case .ideas: String(localized: "Ideas for the topics you make videos about. Nothing is written until you pick one.")
        case .logbook: String(localized: "Save an idea before it disappears, and develop it later.")
        case .voiceFollowing: String(localized: "Read at your own pace: the text moves when you speak and waits when you pause.")
        case .cleanUp: String(localized: "Find pauses and repetitions. You choose what stays.")
        case .autoCaptions: String(localized: "Captions written from your voice, so your audience can follow without sound.")
        case .captionTranslation: String(localized: "Your captions in another language, next to the originals.")
        case .studioVoice: String(localized: "Explore a clearer sound for your voice. Nothing changes until you choose a level.")
        case .skinSmoothing: String(localized: "A subtle finish, if you want one. It starts at zero and you choose the intensity.")
        case .backgrounds: String(localized: "Blur or change the background behind you.")
        case .covers: String(localized: "Choose the first image that introduces your video.")
        case .layers: String(localized: "Show examples while you speak: add a photo or a clip over your video.")
        case .voiceOver: String(localized: "Record a narration over your edit. Nothing records until you press the button.")
        case .remoteControl: String(localized: "Start, pause and scroll the teleprompter from another iPhone or iPad.")
        case .safeZones: String(localized: "See where TikTok, Reels and Shorts put their buttons while you record.")
        case .yourUniverse: String(localized: "See how the videos you share are shaping your universe.")
        }
    }
}
