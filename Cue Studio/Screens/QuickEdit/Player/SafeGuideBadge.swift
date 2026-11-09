//
//  SafeGuideBadge.swift
//  Cue Studio
//

import SwiftUI

/// The safe zone guide's label in the preview's top corner: the app it shows and that it is approximate ("TikTok · approximate"),
/// `ink` on its own dark plate, so it reads over a white frame as over a black one. A tap opens the system menu to switch the
/// platform (the script's is marked) or hide the guide, right there. While a finger moves a text or the captions with the guide
/// hidden, the same label shows on its own (`isInteractive` false), saying which app the dashed area is. It grows with the text size
/// up to Accessibility 2 and gives up the word "approximate" before it would cut the app's name on a narrow preview.
struct SafeGuideBadge: View {
    let look: LookViewModel
    /// The widest it may be: the preview's width less its margins.
    let maxWidth: CGFloat
    var isInteractive = true

    var body: some View {
        if isInteractive {
            Menu {
                Picker(selection: Binding(get: { look.safeGuide }, set: { look.pickSafeGuide($0) })) {
                    ForEach(look.safeGuideOptions, id: \.self) { choice in
                        Text(menuTitle(choice)).tag(choice)
                    }
                } label: {
                    Text("Safe zone")
                }
                .pickerStyle(.inline)
                Button {
                    look.setShowsSafeGuide(false)
                } label: {
                    Label("Hide safe zone", systemImage: "eye.slash")
                }
                .accessibilityIdentifier("edit.safeGuide.hide")
            } label: {
                plate
                    .frame(minHeight: Metrics.hitTarget, alignment: .topLeading)
                    .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
            .accessibilityLabel(Text("Safe zone: \(look.safeGuide.approximateLabel)"))
            .accessibilityHint(Text("Switches the app or hides the guide"))
            .accessibilityIdentifier("edit.safeGuide.badge")
        } else {
            plate
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The label on its plate: the whole of it while it fits, else the app's name alone.
    private var plate: some View {
        ViewThatFits(in: .horizontal) {
            label(look.safeGuide.approximateLabel)
            label(look.safeGuide.label)
        }
        .frame(maxWidth: max(0, maxWidth), alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func label(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "rectangle.dashed")
                .cueFont(.caption, weight: .semibold)
            Text(text)
                .cueFont(.footnote, weight: .semibold)
                .lineLimit(1)
            if isInteractive {
                Image(systemName: "chevron.down")
                    .cueFont(.caption2, weight: .bold)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(minHeight: 30)
        .background(Palette.Editor.safeGuidePlate, in: Capsule())
        .fixedSize()
    }

    /// "TikTok · your script" for the guide the script suggests; the others by name.
    private func menuTitle(_ choice: SafeGuideChoice) -> String {
        guard choice == look.suggestedSafeGuide, case .platform = choice else { return choice.label }
        return String(localized: "\(choice.label) · your script", comment: "Safe zone guide menu in the video editor: the app the script is for")
    }
}
