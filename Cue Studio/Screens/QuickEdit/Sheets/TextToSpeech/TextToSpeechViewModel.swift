//
//  TextToSpeechViewModel.swift
//  Cue Studio
//

import Foundation
import Observation

/// Text to speech's sheet: the text (typed, or the take's script), the language and voice among those on this iPhone, the speed,
/// ▶ to hear the first sentence as it will be, and Add (or Replace, for a spoken voice-over being changed), which makes the whole
/// narration and can be cancelled. The voice's language is the narration's (the voices list says which languages this iPhone
/// speaks). Everything is made on the device (`NarrationMaker`).
@MainActor
@Observable
final class TextToSpeechViewModel {
    enum Phase: Equatable { case writing, previewing, making }

    /// The most a narration says (about three minutes at a natural pace).
    static let characterLimit = 3000
    /// What the preview is played as, in `SoundPreviewing`.
    static let previewKey = "narration.preview"

    var text: String {
        didSet { if text.count > Self.characterLimit { text = String(text.prefix(Self.characterLimit)) } }
    }

    var language: String {
        didSet {
            guard language != oldValue else { return }
            voiceID = voices.first?.id
        }
    }

    var voiceID: String?
    var speed: Double
    private(set) var phase: Phase = .writing
    /// What went wrong the last time, said under the buttons.
    private(set) var problem: String?

    /// The spoken voice-over this replaces; nil adds a new one.
    let replacing: VoiceOverClip?
    /// The take's script without its cues, offered as "Use the script".
    let script: String?

    private let speaker: any NarrationSpeaking
    private let previews: SoundPreviewing
    private let allVoices: [NarrationVoice]
    @ObservationIgnored private var work: Task<Void, Never>?

    init(
        speaker: any NarrationSpeaking, previews: SoundPreviewing, replacing: VoiceOverClip?, script: String?, suggestedLanguage: String
    ) {
        self.speaker = speaker
        self.previews = previews
        self.replacing = replacing
        self.script = script
        allVoices = speaker.voices()
        let spoken = replacing?.spoken
        text = spoken?.text ?? ""
        speed = spoken?.speed ?? 1
        let wanted = spoken?.language ?? suggestedLanguage
        let languages = Set(allVoices.map(\.language))
        language = languages.contains(wanted)
            ? wanted
            : languages.sorted().first { $0.hasPrefix(String(wanted.prefix(2))) } ?? languages.sorted().first ?? wanted
        let offered = NarrationVoice.ordered(allVoices.filter { $0.language == language })
        voiceID = offered.contains { $0.id == spoken?.voiceID } ? spoken?.voiceID : offered.first?.id
    }

    // MARK: - What's offered

    /// The languages this iPhone has voices for, the narration's first.
    var languages: [String] {
        let all = Set(allVoices.map(\.language))
        return [language] + all.subtracting([language]).sorted { Self.name(of: $0).localizedStandardCompare(Self.name(of: $1)) == .orderedAscending }
    }

    /// The language's voices, the better ones first.
    var voices: [NarrationVoice] {
        NarrationVoice.ordered(allVoices.filter { $0.language == language })
    }

    /// Only compact voices in this language: the note says where the better ones are downloaded.
    var hasOnlyCompactVoices: Bool {
        !voices.isEmpty && voices.allSatisfy { $0.quality == .standard }
    }

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canMake: Bool { !isEmpty && voiceID != nil && phase != .making }
    var isPreviewPlaying: Bool { previews.playingKey == Self.previewKey }

    /// "1,234 / 3,000".
    var countLabel: String {
        "\(text.count.formatted()) / \(Self.characterLimit.formatted())"
    }

    /// "Português (Brasil)", in the interface's language.
    static func name(of language: String) -> String {
        Locale.current.localizedString(forIdentifier: language) ?? language
    }

    func useScript() {
        guard let script else { return }
        text = script
    }

    // MARK: - Hearing and making

    private var narration: SpokenNarration? {
        guard let voiceID, !isEmpty else { return nil }
        return SpokenNarration(text: text.trimmingCharacters(in: .whitespacesAndNewlines), voiceID: voiceID, language: language, speed: speed)
    }

    /// ▶: the first sentence as it will be; ■ stops it.
    func togglePreview() {
        if isPreviewPlaying || phase == .previewing {
            stopPreview()
            return
        }
        guard let narration, phase == .writing else { return }
        problem = nil
        phase = .previewing
        work = Task { [speaker, previews] in
            do {
                let url = try await NarrationMaker.preview(narration, speaker: speaker)
                guard !Task.isCancelled else { return }
                previews.play(url, key: Self.previewKey)
            } catch is CancellationError {
            } catch {
                problem = String(localized: "Couldn't speak this text with this voice · Try another voice")
            }
            if phase == .previewing { phase = .writing }
        }
    }

    func stopPreview() {
        if phase == .previewing {
            work?.cancel()
            phase = .writing
        }
        previews.stop()
    }

    /// Add or Replace: makes the whole narration, then hands it over.
    func make(onMade: @escaping @MainActor (SpokenNarration, _ fileName: String, _ duration: TimeInterval) -> Void) {
        guard let narration, canMake else { return }
        stopPreview()
        problem = nil
        phase = .making
        work = Task { [speaker] in
            do {
                let made = try await NarrationMaker.make(narration, speaker: speaker)
                guard !Task.isCancelled else {
                    EditMediaFiles.remove([made.fileName])
                    return
                }
                phase = .writing
                onMade(narration, made.fileName, made.duration)
            } catch is CancellationError {
                phase = .writing
            } catch {
                phase = .writing
                problem = String(localized: "Couldn't make the voice-over · Try again or pick another voice")
            }
        }
    }

    /// Cancel while making: the narration isn't added and nothing is left behind.
    func cancel() {
        work?.cancel()
        work = nil
        phase = .writing
        previews.stop()
    }
}
