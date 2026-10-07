//
//  VoiceExamplesField.swift
//  Cue Studio
//

import SwiftUI

/// Proof: up to three things the creator wrote themself (a caption, a post, a past script) so Cue can hear how they write, and the scripts they
/// approved with "Sounds like me", which Cue also learns from. Two to four sentences each; text with words Apple Intelligence won't learn from is
/// refused. "I said or wrote this myself" has to be on before an example is added. Stays on the iPhone.
struct VoiceExamplesField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ScriptLibraryService.self) private var library
    @Environment(ToastService.self) private var toast
    @State private var text = ""
    @State private var feedback: String?
    @State private var isOwn = false
    @State private var showsImport = false

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            importCard
            ForEach(current.examples) { example in
                row(example, remove: { profile.removeExample(example.id) }, identifier: "voice.example.remove")
            }
            if current.examples.count < VoiceExample.limit {
                adding
            } else {
                Text("Max 3 examples · tap ✕ to swap one")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            if !current.approvedSamples.isEmpty { approved }
            Text("Teaches how you talk — never reused for stories, opinions or results. Stays on this iPhone.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - What they imported

    /// Bring a lot of writing at once, or see what was brought and forget it.
    private var importCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if current.excerpts.isEmpty {
                Button { showsImport = true } label: {
                    Label("Import my writing", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("voice.import")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Imported from your writing").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    // Side by side when they fit, one under the other in the languages whose words are longer.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { moreButton; forgetButton; Spacer(minLength: 0) }
                        VStack(alignment: .leading, spacing: 8) { moreButton; forgetButton }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                // What stays on the iPhone, to read and to take out one by one.
                DisclosureGroup {
                    VStack(spacing: 8) {
                        ForEach(current.excerpts) { excerpt in
                            ExcerptRow(excerpt: excerpt) { profile.removeExcerpt(excerpt.id) }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Excerpts: \(current.excerpts.count)").font(.footnote).foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("voice.import.count")
                }
                .tint(Palette.ink2)
                .accessibilityIdentifier("voice.import.excerpts")
            }
        }
        .sheet(isPresented: $showsImport) { WritingImportSheet() }
    }

    private var moreButton: some View {
        Button("Import more") { showsImport = true }
            .buttonStyle(.cueSecondary(.compact, expands: false))
            .accessibilityIdentifier("voice.import.more")
    }

    private var forgetButton: some View {
        Button("Forget") { profile.clearImportedWriting() }
            .buttonStyle(.cueSecondary(.compact, expands: false))
            .accessibilityIdentifier("voice.import.forget")
    }

    // MARK: - What they wrote

    private func row(_ example: VoiceExample, remove: @escaping () -> Void, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                if let source = example.source {
                    Text(source.uppercased()).font(CueStudioFont.hud).tracking(0.6).foregroundStyle(Palette.inkHint)
                }
                Text("“\(example.text)”")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(Palette.ink)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.ink3)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            }
            .accessibilityLabel(Text("Remove"))
            .accessibilityIdentifier(identifier)
        }
        .padding(.leading, 14)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var adding: some View {
        VStack(alignment: .leading, spacing: 12) {
            VoiceFieldLabel(String(localized: "Add an example"))
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
        }
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

    // MARK: - What Cue learned

    private var approved: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "✦ Cue also learned from"), detail: String(localized: "scripts you approved"))
            ForEach(current.approvedSamples.reversed()) { sample in
                row(sample, remove: { profile.removeApprovedSample(sample.id) }, identifier: "voice.approved.remove")
            }
        }
    }
}
