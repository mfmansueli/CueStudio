#if DEBUG
import SwiftUI

/// Explicit native experiment, separate from ordinary Apple generation and purchases.
struct UltraLabView: View {
    @Environment(ScriptStarter.self) private var starter
    @Environment(ScriptLibraryService.self) private var library
    @Environment(PresentationService.self) private var presentation
    @State private var model = UltraLabViewModel()

    var body: some View {
        Form {
            Section {
                Text(verbatim: "Native Ultra lab · Google Gemini · global")
                    .foregroundStyle(Palette.ink)
                Text("Ultra sends your request and voice preferences to Google to write and polish your script. Writing samples, videos and audio are not sent. Google Cloud does not train models on this data without permission; retention may apply. You can stop using Ultra at any time.")
                    .foregroundStyle(Palette.ink2)
                Toggle("Allow Google processing", isOn: $model.consents)
                    .disabled(model.isWorking)
                DisclosureGroup("What Cue sends") {
                    Text(UltraLabPrompt.context(request)).textSelection(.enabled).foregroundStyle(Palette.ink2)
                }
            }
            Section("Prompt") {
                TextEditor(text: $model.prompt).frame(minHeight: 140).accessibilityIdentifier("ultra.prompt")
                Button("Generate") { model.generate(request) }
                    .disabled(!model.consents || model.isWorking || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("ultra.generate")
                if model.isWorking { ProgressView() }
                Text(verbatim: model.status).foregroundStyle(Palette.ink2)
                Button("Cancel") { model.revoke() }
            }
            if !model.result.isEmpty {
                Section("Script") {
                    Text(model.result).textSelection(.enabled).foregroundStyle(Palette.ink)
                    Button("Save") {
                        let script = library.create(title: model.prompt, text: model.result, platform: starter.platform)
                        presentation.openScript(script.id, editing: true)
                    }
                }
            }
            if !model.draft.isEmpty {
                Section("Draft") { Text(model.draft).textSelection(.enabled).foregroundStyle(Palette.ink2) }
            }
        }
        .navigationTitle(Text(verbatim: "AI Scripts Ultra"))
        .onDisappear { model.revoke() }
    }

    private var request: ScriptRequest {
        starter.factory.request(idea: model.prompt, platform: starter.platform, format: nil)
    }
}
#endif
