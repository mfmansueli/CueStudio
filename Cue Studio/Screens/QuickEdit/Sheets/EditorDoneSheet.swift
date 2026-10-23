//
//  EditorDoneSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Is it ready to post?": asked every time the creator taps Done. Four answers, each saying where
/// the video goes (SHARED, SAVED, READY, IN EDIT). The first, the way most videos end, is yellow.
/// No platform names: sharing is generic, the app is picked in the share sheet. Swiping the sheet
/// down goes back to the editor.
struct EditorDoneSheet: View {
    /// "1:02": the edit's length, under "EDIT SAVED".
    let duration: String
    /// The height the content needs, so the sheet is exactly that tall (the four answers always show).
    var onMeasure: (CGFloat) -> Void = { _ in }
    let onAnswer: (EditorOutcome) -> Void

    /// An answer's small capitals line, growing with the text size.
    @ScaledMetric(relativeTo: .caption2) private var smallLabelSize: CGFloat = 10

    var body: some View {
        // With the largest text sizes the answers are taller than the screen: the sheet stops at its
        // full height and they scroll, starting at the top ("EDIT SAVED" and the question under the grabber).
        ScrollView {
            content
        }
        .scrollBounceBehavior(.basedOnSize)
        // Centered in the sheet while it fits (as the sheet is a little taller than the answers); from the top when it scrolls.
        .defaultScrollAnchor(.center, for: .alignment)
        .defaultScrollAnchor(.top, for: .initialOffset)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("edit.doneSheet")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Edit saved · \(duration)")
                    .textCase(.uppercase)
                    .font(.system(.caption2, design: .monospaced, weight: .heavy))
                    .interfaceTracking(1)
                    .foregroundStyle(Palette.accText)
                Text("Is it ready to post?")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 8) {
                option(.share, title: "Yes, share to social media", detail: "Pick the app in the share sheet", result: .shared, isPrimary: true)
                option(.download, title: "Download video", detail: "Saves to Photos · post it anywhere", result: nil)
                option(.ready, title: "Ready, I’ll post later", detail: "Goes to Ready in Takes", result: .ready)
                option(.notYet, title: "Not yet, I’ll come back", detail: "Stays in edit · autosaved", result: .edit)
            }
        }
        .padding(EdgeInsets(top: 22, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onMeasure($0) }
        .accessibilityElement(children: .contain)
    }

    private func option(
        _ outcome: EditorOutcome, title: LocalizedStringKey, detail: LocalizedStringKey, result: TakeStage?, isPrimary: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        return Button { onAnswer(outcome) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(isPrimary ? Palette.accInk2 : Palette.ink2)
                }
                Spacer(minLength: 8)
                pill(result, isPrimary: isPrimary)
            }
            .foregroundStyle(isPrimary ? Palette.accInk : Palette.ink)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(isPrimary ? Palette.acc : Palette.surface2, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.done.\(outcome.rawValue)")
    }

    /// "● SHARED", "● SAVED", "● READY", "● IN EDIT": where the answer leaves the video.
    @ViewBuilder
    private func pill(_ stage: TakeStage?, isPrimary: Bool) -> some View {
        let label: String = stage?.badgeLabel ?? String(localized: "Saved")
        let tint: Color = isPrimary ? Palette.accInk : (stage?.tint ?? Palette.ink2)
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(label).textCase(.uppercase).lineLimit(1)
        }
        .font(.system(size: smallLabelSize, weight: .heavy, design: .monospaced))
        .interfaceTracking(0.5)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(isPrimary ? Color.black.opacity(0.12) : Palette.fill, in: Capsule())
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    EditorDoneSheet(duration: "1:02", onAnswer: { _ in })
        .background(Palette.surface)
}
#endif
