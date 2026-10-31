//
//  UltraPrivacyView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Privacy & AI data › What Ultra AI sends: everything the one-line consent leaves out (App Review 5.1.2(i): where personal data goes,
/// to which third party, for what, and how to stop it). What goes to Google and when, what never does, what Google does with it, and the
/// requests exactly as they go out (`UltraPayloadView`). The consent stays one line (the owner, 31/10/2026); this page is the detail it points to.
struct UltraPrivacyView: View {
    @Environment(ScriptStarter.self) private var starter

    var body: some View {
        List {
            Section {
                row("Your idea, exactly as you type it, or a format’s answers", position: .first)
                row("The language, platform, format and length", position: .middle)
                row("Your My Cue Voice preferences: who you are, your audience and how you speak", position: .middle)
                row("The inspiration the idea came from, a sponsored script’s brand details and words you ask it to say", position: .middle)
                row("The draft between steps, for the check and the polish", position: .middle)
                row("With Fit to time, on a script Ultra AI wrote: that script with your edits", position: .last)
            } header: {
                CueSectionHeader("Sent to Google")
            } footer: {
                Text("Only when you pick Ultra AI: up to 3 requests for a script (draft, check and polish) and 1 for Fit to time. Nothing is sent in the background.")
                    .foregroundStyle(Palette.ink2)
            }
            Section {
                row("Your name and @handle, writing examples, imported excerpts, other scripts, videos, audio and photos", position: .only)
            } header: {
                CueSectionHeader("Never sent")
            }
            Section {
                row("Google runs its AI model to write, check, polish or fit the script, and sends the text back.", position: .first)
                row("Under Google Cloud’s terms, Google doesn’t use it to train its models. It may keep it for up to 24 hours to answer faster, and may log requests to detect abuse.", position: .middle)
                row("A check from Google (Firebase App Check) confirms each request comes from Cue.", position: .last)
            } header: {
                CueSectionHeader("What Google does with it")
            }
            Section {
                NavigationLink {
                    ScrollView {
                        UltraPayloadView(payload: starter.ultraPreview())
                            .padding(EdgeInsets(top: 12, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
                    }
                    .skyBackground()
                    .navigationTitle("Requests to Google")
                    .navigationBarTitleDisplayMode(.inline)
                    .accessibilityIdentifier("privacy.ultraRequests.screen")
                } label: {
                    Text("See the requests, word for word").foregroundStyle(Palette.ink).frame(minHeight: Metrics.listRowContent)
                }
                .accessibilityIdentifier("privacy.ultraRequests")
                .cardRowBackground(position: .first)
                if let url = AppLinks.googleCloudDataTerms {
                    Link(destination: url) {
                        Text("Google Cloud’s data terms").foregroundStyle(Palette.accText).frame(minHeight: Metrics.listRowContent)
                    }
                    .cardRowBackground(position: .last)
                }
            } footer: {
                Text("Turn Ultra AI off in Privacy & AI data and nothing more goes to Google. Scripts it already wrote stay on this iPhone. Apple Intelligence doesn’t change.")
                    .foregroundStyle(Palette.ink2)
            }
        }
        .cueGroupedList()
        .navigationTitle("What Ultra AI sends")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacy.ultraDetail.screen")
    }

    private func row(_ text: LocalizedStringKey, position: CardRowPosition) -> some View {
        Text(text)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: Metrics.listRowContent, alignment: .leading)
            .padding(.vertical, 4)
            .cardRowBackground(position: position)
    }
}

#if DEBUG
#Preview {
    NavigationStack { UltraPrivacyView() }
        .previewEnvironment()
}
#endif
