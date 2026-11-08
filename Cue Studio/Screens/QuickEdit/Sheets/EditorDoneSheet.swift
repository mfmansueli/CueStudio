//
//  EditorDoneSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Is it ready to post?": asked every time the creator taps Done. Four answers, each saying where
/// the video goes (SHARED, IN PHOTOS, READY, IN EDIT). The first, the way most videos end, is yellow.
/// No platform names: sharing is generic, the app is picked in the share sheet. With the last free export (or none) left, one line under
/// the question says so, where the creator decides (owner, 06/11/2026: no new flow); so does a font that isn't here
/// (`EditorDoneFontNote`). Under the answers, a quiet "Export options · 1080p · captions on" turns the sheet to its second page (F19, no sheet
/// over this one): the review's Export options for this edit (D11), the ones Share and Download use, with "‹" back to the answers. The sheet
/// is as tall as the page it shows. Swiping it down goes back to the editor.
struct EditorDoneSheet<Options: View>: View {
    /// "1:02": the edit's length, under "EDIT SAVED".
    let duration: String
    /// "LAST FREE EXPORT" or "0 OF 3 LEFT · EXPORT WITH PRO" under the question, when sharing or downloading this edit would use the last free
    /// export or needs Pro (`TakeReviewViewModel.doneExportNote`); nil on Pro, with more left, or for a video already out.
    var exportNote: FreeExportLabels.Label?
    /// "A font is still downloading · …" when some words would come out in the system's face (`EditorDoneFontNote`); nil when every
    /// word has its font.
    var fontNote: String?
    /// "1080p · captions on" (or "606×1080 · …" when the format's crop makes the file smaller): what Share and Download make this edit with
    /// (`TakeReviewViewModel.outputSummary(for:)`); nil hides the line and the second page.
    var exportOptions: String?
    /// The second page's options (`ExportOptionsForm`, the same the review's sheet shows).
    @ViewBuilder var options: () -> Options
    /// The height the content needs, so the sheet is exactly that tall (the four answers always show).
    var onMeasure: (CGFloat) -> Void = { _ in }
    let onAnswer: (EditorOutcome) -> Void

    private enum Page {
        case answers, exportOptions
    }

    @State private var page = Page.answers
    @AccessibilityFocusState private var focusesOptionsTitle: Bool
    @AccessibilityFocusState private var focusesOptionsLine: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        // Both pages in one place while one slides over the other, so the measured height is the page that stays.
        ZStack(alignment: .topLeading) {
            switch page {
            case .answers:
                answers.transition(pageTransition(from: .leading))
            case .exportOptions:
                optionsPage.transition(pageTransition(from: .trailing))
            }
        }
        .padding(EdgeInsets(top: 22, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onMeasure($0) }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Answers

    private var answers: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Edit saved · \(duration)")
                    .textCase(.uppercase)
                    .monoFont(.caption2, weight: .heavy)
                    .interfaceTracking(1)
                    .foregroundStyle(Palette.accText)
                Text("Is it ready to post?")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                if let exportNote {
                    // The free exports' own words and colours (Share's meter): yellow for the last one, orange once they are gone.
                    Text(exportNote.text)
                        .monoFont(.caption2, weight: .heavy)
                        .interfaceTracking(1)
                        .foregroundStyle(exportNote.tone == .exhausted ? Palette.warnText : Palette.accText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                        .accessibilityIdentifier("edit.done.exportNote")
                }
                if let fontNote {
                    Text(fontNote)
                        .textCase(.uppercase)
                        .monoFont(.caption2, weight: .heavy)
                        .interfaceTracking(1)
                        .foregroundStyle(Palette.warnText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                        .accessibilityIdentifier("edit.done.fontNote")
                }
            }
            .padding(.horizontal, 4)
            VStack(spacing: 8) {
                option(.share, title: "Yes, share to social media", detail: "Pick the app in the share sheet", result: .shared, isPrimary: true)
                option(.download, title: "Download video", detail: "Saves to Photos · post it anywhere", result: nil)
                option(.ready, title: "Ready, I’ll post later", detail: "Goes to Ready in Takes", result: .ready)
                option(.notYet, title: "Not yet, I’ll come back", detail: "Stays in edit · autosaved", result: .edit)
            }
            if let exportOptions {
                // Quieter than the notes above (footnote, `ink2`, no capitals): there for whoever needs it.
                ExportOptionsLine(summary: exportOptions, identifier: "edit.done.exportOptions") { turn(to: .exportOptions) }
                    .frame(maxWidth: .infinity)
                    .padding(.top, -6)
                    .accessibilityFocused($focusesOptionsLine)
            }
        }
    }

    private func option(
        _ outcome: EditorOutcome, title: LocalizedStringKey, detail: LocalizedStringKey, result: TakeStage?, isPrimary: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        let words = VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(isPrimary ? Palette.accInk2 : Palette.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        return Button { onAnswer(outcome) } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    // The title and detail get the whole width (they wrap between words); the pill goes under them (F17: beside them,
                    // at these sizes, it left "Download" a letter per line).
                    VStack(alignment: .leading, spacing: 8) {
                        words
                        pill(result, isPrimary: isPrimary)
                    }
                    .padding(.vertical, 12)
                } else {
                    HStack(spacing: 10) {
                        words
                        // Whole, always: the title and detail wrap beside it instead (owner, 02/11/2026: no label is ever cut).
                        pill(result, isPrimary: isPrimary)
                            .fixedSize()
                            .layoutPriority(1)
                    }
                }
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

    /// "● SHARED", "● IN PHOTOS", "● READY", "● IN EDIT": where the answer leaves the video (the edit itself is saved in every
    /// case, as the line above the question says).
    @ViewBuilder
    private func pill(_ stage: TakeStage?, isPrimary: Bool) -> some View {
        let label: String = stage?.badgeLabel ?? String(localized: "In Photos")
        let tint: Color = isPrimary ? Palette.accInk : (stage?.tint ?? Palette.ink2)
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(label).textCase(.uppercase).lineLimit(1)
        }
        .monoFont(size: smallLabelSize, weight: .heavy)
        .interfaceTracking(0.5)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        // Grows with the text: a fixed height cut the letters at the largest sizes.
        .frame(minHeight: 22)
        .background(isPrimary ? Color.black.opacity(0.12) : Palette.fill, in: Capsule())
        .accessibilityHidden(true)
    }

    // MARK: - Export options

    /// The second page: "‹ Export options" and the options, nothing else (the free exports and the font stay on the answers' page).
    private var optionsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 4) {
                Button { turn(to: .answers) } label: {
                    Image(systemName: "chevron.backward")
                        .font(.fixed(17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("edit.done.optionsBack")
                Text("Export options")
                    .cueFont(.headline, weight: .semibold)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focusesOptionsTitle)
                Spacer(minLength: 0)
            }
            .padding(.leading, -12)
            options()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.done.optionsPage")
    }

    private func turn(to next: Page) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.32)) { page = next }
        // VoiceOver lands where the page begins (its title), and back on the line that opened it.
        focusesOptionsTitle = next == .exportOptions
        focusesOptionsLine = next == .answers
    }

    /// A page slides in from its side (the answers from the left, the options from the right); with Reduce Motion it only fades.
    private func pageTransition(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}

#if DEBUG
#Preview {
    EditorDoneSheet(
        duration: "1:02", exportNote: FreeExportLabels.meter(left: 1), exportOptions: "1080p · captions on",
        options: { Text(verbatim: "Options") }, onAnswer: { _ in }
    )
    .background(Palette.surface)
}
#endif
