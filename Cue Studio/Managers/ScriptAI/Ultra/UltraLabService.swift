#if DEBUG
import FirebaseAI
import FirebaseAppCheck
import FirebaseCore
import Foundation

/// Debug-only native experiment. Config is copied into Documents, never included in Release.
@MainActor
final class UltraLabService {
    private let defaults: UserDefaults
    private var ai: FirebaseAI?
    private(set) var draft = ""
    private(set) var stage = ""

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func generate(context: String, consent: Bool, progress: (String) -> Void) async throws -> String {
        guard consent else { throw CocoaError(.userCancelled) }
        let backend = try configuredBackend()
        progress("Draft")
        draft = try await call(backend, instructions: UltraLabPrompt.instructions, prompt: context)
        try Task.checkCancellation()
        progress("Review")
        let final = try await call(backend, instructions: UltraLabPrompt.reviewInstructions,
                                   prompt: context + "\n\nDraft to polish:\n" + draft)
        return final
    }

    private func configuredBackend() throws -> FirebaseAI {
        if let ai { return ai }
        let path = URL.documentsDirectory.appending(path: "UltraLab-GoogleService-Info.plist").path
        guard let options = FirebaseOptions(contentsOfFile: path), options.projectID == "cue-script-ai-lab",
              options.bundleID == Bundle.main.bundleIdentifier else { throw CocoaError(.fileReadCorruptFile) }
        if FirebaseApp.app(name: "CueUltraLab") == nil {
            AppCheck.setAppCheckProviderFactory(UltraLabAppCheckFactory())
            FirebaseApp.configure(name: "CueUltraLab", options: options)
        }
        guard let app = FirebaseApp.app(name: "CueUltraLab") else { throw CocoaError(.fileReadCorruptFile) }
        let backend = FirebaseAI.firebaseAI(app: app, backend: .agentPlatform(location: "global"))
        ai = backend
        return backend
    }

    private func call(_ backend: FirebaseAI, instructions: String, prompt: String) async throws -> String {
        try Task.checkCancellation()
        let key = "ultraLab.sdkCalls.v1"
        let used = defaults.integer(forKey: key)
        guard used < 10 else { throw CocoaError(.validationMultipleErrors) }
        defaults.set(used + 1, forKey: key)
        let model = backend.generativeModel(
            modelName: "gemini-3.5-flash", generationConfig: GenerationConfig(maxOutputTokens: 4096),
            systemInstruction: ModelContent(role: "system", parts: instructions), requestOptions: RequestOptions(timeout: 90)
        )
        let response = try await model.generateContent(prompt)
        guard response.candidates.first?.finishReason == .stop,
              let text = response.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw CocoaError(.coderReadCorrupt)
        }
        return text
    }
}
#endif
