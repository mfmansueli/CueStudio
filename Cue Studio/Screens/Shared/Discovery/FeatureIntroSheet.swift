//
//  FeatureIntroSheet.swift
//  Cue Studio
//

import SwiftUI

/// A tool introduced in the app, in the invitations' one form (`InviteSheet`): its name, one clear benefit, what it uses or needs, **Try it**
/// and **Not now** (also the ✕: not before 30 days), and a quiet "Don't suggest this" under them (the tool is hidden until Settings ›
/// Personalize › Hidden suggestions brings it back). "Try it" opens the tool on the creator's own script or take; nothing in it runs until
/// they use it there.
struct FeatureIntroSheet: View {
    let request: FeatureIntroRequest
    let onTry: () -> Void
    let onNotNow: () -> Void
    let onDecline: () -> Void
    /// Closed with the ✕ or a swipe: counted as "Not now".
    var onDismissed: () -> Void = {}

    private var note: String? { FeatureCatalog.intro(for: request.feature)?.note.text }

    var body: some View {
        InviteSheet(
            title: request.feature.name, line: request.feature.benefit, uses: note, primaryTitle: String(localized: "Try it"),
            onPrimary: onTry, onNotNow: onNotNow, link: (String(localized: "Don’t suggest this"), onDecline), onDismissed: onDismissed,
            identifier: "featureIntro", primaryIdentifier: "featureIntro.try", notNowIdentifier: "featureIntro.notNow",
            linkIdentifier: "featureIntro.decline"
        )
    }
}

#if DEBUG
#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        FeatureIntroSheet(
            request: FeatureIntroRequest(feature: .cleanUp, destination: .scripts, projectKey: "preview", source: .inApp),
            onTry: {}, onNotNow: {}, onDecline: {}
        )
    }
    .previewEnvironment()
}
#endif
