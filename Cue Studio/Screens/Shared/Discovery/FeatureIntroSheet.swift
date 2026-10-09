//
//  FeatureIntroSheet.swift
//  Cue Studio
//

import SwiftUI

/// A tool introduced in the app: its name, one clear benefit, what it uses or needs, **Try it** and **Not now**, and a quiet "Don't suggest
/// this" under them. "Try it" opens the tool on the creator's own script or take; nothing in it runs until they use it there.
struct FeatureIntroSheet: View {
    let request: FeatureIntroRequest
    let onTry: () -> Void
    let onNotNow: () -> Void
    let onDecline: () -> Void

    private var symbol: String { FeatureCatalog.intro(for: request.feature)?.symbol ?? "sparkles" }
    private var note: String? { FeatureCatalog.intro(for: request.feature)?.note.text }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.aiText)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                SheetHeader(title: request.feature.name, subtitle: request.feature.benefit)
            }
            if let note {
                Label(note, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("featureIntro.note")
            }
            VStack(spacing: 8) {
                Button(action: onTry) { Text("Try it").frame(maxWidth: .infinity) }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("featureIntro.try")
                Button(action: onNotNow) { Text("Not now").frame(maxWidth: .infinity) }
                    .buttonStyle(.cueSecondary(.large))
                    .accessibilityIdentifier("featureIntro.notNow")
                Button("Don’t suggest this", action: onDecline)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.hitTarget)
                    .accessibilityIdentifier("featureIntro.decline")
            }
        }
        .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
        .fittedSheet()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("featureIntro.sheet")
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
