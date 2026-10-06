//
//  EmptyState.swift
//  Cue Studio
//

import SwiftUI

/// The one empty-state pattern (v29): an 88 pt ring with a violet core and a star orbiting it, a title, one line, one yellow
/// action and, when there is a second way out, a text link. Motion is ambient and slow (one turn in 9 s); it is
/// still with Reduce Motion and when the app is not active, with the star at the top right.
struct EmptyState: View {
    var icon: EmptyStateIcon = .star
    var title: LocalizedStringKey
    /// One sentence, 60 characters or fewer.
    var message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    /// A small dot before the action's words (the red one of "● Record").
    var actionDot: Color?
    var action: () -> Void = {}
    var linkTitle: LocalizedStringKey?
    var link: (() -> Void)?
    var accessibilityPrefix = "emptyState"

    var body: some View {
        VStack(spacing: 14) {
            EmptyStateMark(icon: icon)
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.44)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.system(size: 15))
                    .lineSpacing(2)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            if let actionTitle {
                Button(action: action) {
                    HStack(spacing: 8) {
                        if let actionDot { Circle().fill(actionDot).frame(width: 10, height: 10) }
                        Text(actionTitle)
                    }
                }
                    .buttonStyle(.cuePrimary(.regular, expands: false))
                    .padding(.top, 4)
                    .accessibilityIdentifier("\(accessibilityPrefix).action")
            }
            if let linkTitle, let link {
                Button(action: link) {
                    Text(linkTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink.opacity(0.8))
                        .frame(minHeight: Metrics.hitTarget)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(accessibilityPrefix).link")
            }
        }
        .padding(.horizontal, Metrics.textGutter)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityPrefix)
    }
}

#if DEBUG
#Preview {
    EmptyState(
        title: "No takes yet", message: "Record one and it shows up here.", actionTitle: "Record a take", action: {},
        linkTitle: "Write a script first", link: {}
    )
    .padding()
    .background(Palette.bg)
}
#endif
