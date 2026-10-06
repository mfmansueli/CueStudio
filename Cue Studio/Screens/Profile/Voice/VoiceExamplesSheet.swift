//
//  VoiceExamplesSheet.swift
//  Cue Studio
//

import SwiftUI

/// Proof (9.3): up to three things the creator wrote themself (a caption, a post, a past script) so Cue can hear how they
/// write. Two to four sentences each; text with words Apple Intelligence won't learn from is refused. Stays on the iPhone.
struct VoiceExamplesSheet: View {
    var body: some View {
        VoiceExamplesBody()
            .cueSheetChrome()
            .presentationDetents([.large])
    }
}

/// What is in the examples sheet, without the sheet (the question sheet shows it for the last question too). "I said or wrote this
/// myself" has to be on before an example is added (08 X1); the text can be typed, pasted or taken from one of the creator's scripts.
struct VoiceExamplesBody: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ScriptLibraryService.self) private var library
    @Environment(ToastService.self) private var toast
    @State private var text = ""
    @State private var feedback: String?
    @State private var isOwn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(
                    title: String(localized: "Examples"), subtitle: String(localized: "A caption, post or past script. 2–4 sentences.")
                )
                ForEach(profile.profile.examples) { example in
                    HStack(alignment: .top, spacing: 10) {
                        Text("“\(example.text)”")
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(Palette.ink)
                            .lineLimit(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { profile.removeExample(example.id) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.ink3)
                                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                        }
                        .accessibilityLabel(Text("Remove"))
                        .accessibilityIdentifier("voice.example.remove")
                    }
                    .padding(.leading, 14)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if profile.profile.examples.count < VoiceExample.limit {
                    TextField(String(localized: "Add 2–4 sentences"), text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                        .accessibilityIdentifier("voice.exampleField")
                    if let feedback {
                        Text(feedback).font(.footnote).foregroundStyle(Palette.warnText).accessibilityIdentifier("voice.feedback")
                    }
                    sourceButtons
                    Toggle("I said or wrote this myself", isOn: $isOwn)
                        .font(.subheadline)
                        .tint(Palette.successText)
                        .accessibilityIdentifier("voice.exampleOwn")
                    Button("Add an example", action: add)
                        .buttonStyle(.cuePrimary())
                        .disabled(!isOwn || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("voice.exampleAdd")
                } else {
                    Text("Max 3 examples · tap ✕ to swap one")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .accessibilityIdentifier("voice.sheet.examples")
    }

    /// Paste, or pick one of the creator's own scripts.
    private var sourceButtons: some View {
        HStack(spacing: 8) {
            Button { text = UIPasteboard.general.string ?? text } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.cueSecondary(.compact, expands: false))
            .accessibilityIdentifier("voice.examplePaste")
            if !library.scripts.isEmpty {
                Menu {
                    ForEach(library.scripts.prefix(8)) { script in
                        Button(script.displayTitle) { text = script.text }
                    }
                } label: {
                    Label("My scripts", systemImage: "doc.text")
                }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("voice.exampleScripts")
            }
            Spacer(minLength: 0)
        }
    }

    private func add() {
        switch profile.addExample(text) {
        case .added:
            text = ""
            isOwn = false
            feedback = nil
            toast.show(String(localized: "Example saved"))
        case .rejected(let check):
            feedback = check == .blocked ? VoiceTextValidator.checkExample(text).message : String(localized: "Add 2–4 sentences")
        case .alreadyThere:
            feedback = String(localized: "Already added.")
        case .limit(let message):
            toast.show(message)
        default:
            break
        }
    }
}
