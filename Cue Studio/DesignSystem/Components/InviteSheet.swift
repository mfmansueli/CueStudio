//
//  InviteSheet.swift
//  Cue Studio
//

import SwiftUI

/// The one form of a sheet that asks "do you want this?" (owner, 30/10/2026): the system's sheet fitted to its content, Cue's mark (the
/// ring with its orbiting star) as the art, a 22 pt title, one line, the line of what it uses, a yellow button and "Not now", and at most one
/// quiet link under them. The system's ✕ (or a swipe down) counts as "Not now" (`onDismissed`). Used by the invitation to allow notifications
/// and a tool's introduction.
struct InviteSheet: View {
    let title: String
    let line: String
    /// What it uses or needs ("Uses notifications · change it anytime in Settings").
    var uses: String?
    let primaryTitle: String
    let onPrimary: () -> Void
    let onNotNow: () -> Void
    /// A quiet link under the buttons ("Don't suggest this").
    var link: (title: String, action: () -> Void)?
    /// Closed without an answer (the ✕, a swipe down): what "Not now" records, without closing anything else.
    let onDismissed: () -> Void
    /// The identifiers start with it: "notificationInvite" names "notificationInvite.sheet", ".allow"-style buttons are given below.
    let identifier: String
    var primaryIdentifier: String
    var notNowIdentifier: String
    var linkIdentifier: String?

    @State private var answered = false

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateMark()
                .padding(.top, 4)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(title)
                    .cueFont(22, weight: .bold)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(line)
                    .cueFont(.subheadline)
                    .foregroundStyle(Palette.ink2)
                if let uses {
                    Text(uses)
                        .cueFont(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .padding(.top, 2)
                        .accessibilityIdentifier("\(identifier).uses")
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                Button { answer(onPrimary) } label: { Text(primaryTitle).frame(maxWidth: .infinity) }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier(primaryIdentifier)
                Button { answer(onNotNow) } label: { Text("Not now").frame(maxWidth: .infinity) }
                    .buttonStyle(.cueSecondary(.large))
                    .accessibilityIdentifier(notNowIdentifier)
                if let link {
                    Button(link.title) { answer(link.action) }
                        .cueFont(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .frame(minHeight: Metrics.hitTarget)
                        .accessibilityIdentifier(linkIdentifier ?? "\(identifier).link")
                }
            }
        }
        .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
        .fittedSheet()
        .onDisappear { if !answered { onDismissed() } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier).sheet")
    }

    private func answer(_ action: () -> Void) {
        answered = true
        action()
    }
}

#if DEBUG
#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        InviteSheet(
            title: "Want Cue to remind you to finish this video?", line: "One notification when something is waiting, at most one a day.",
            uses: "Uses notifications · change it anytime in Settings", primaryTitle: "Allow notifications", onPrimary: {}, onNotNow: {},
            onDismissed: {}, identifier: "preview", primaryIdentifier: "preview.allow", notNowIdentifier: "preview.notNow"
        )
    }
    .previewEnvironment()
}
#endif
