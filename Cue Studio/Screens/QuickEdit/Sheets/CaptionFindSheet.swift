//
//  CaptionFindSheet.swift
//  Cue Studio
//

import SwiftUI

/// Find and replace, over the editor (half height, so the video stays in view): a word to find and what to put in its
/// place, then every line that has it, in play order, with the word marked. **Replace** on a row changes that one match;
/// **Replace all** changes every match in one undo step. Tapping a row takes the playhead to its line. Only the words
/// change: the lines keep their times.
struct CaptionFindSheet: View {
    @Bindable var viewModel: QuickEditViewModel

    @State private var query = ""
    @State private var replacement = ""
    @FocusState private var focused: Field?

    private enum Field {
        case find, replace
    }

    private var matches: [CaptionFindReplace.Match] {
        viewModel.captionMatches(for: query)
    }

    var body: some View {
        let matches = matches
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: String(localized: "Find and replace"), subtitle: String(localized: "In every caption line. The timing stays."))
            field(
                String(localized: "Find"), text: $query, prompt: String(localized: "Word to find"), systemImage: "magnifyingglass",
                field: .find, identifier: "edit.captionFind.query"
            )
            field(
                String(localized: "Replace with"), text: $replacement, prompt: String(localized: "New word"),
                systemImage: "arrow.left.arrow.right", field: .replace, identifier: "edit.captionFind.replacement"
            )
            summary(matches)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(matches) { match in
                        row(match)
                        Divider().overlay(Palette.separator)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            PanelButton(
                label: String(localized: "Replace all"), systemImage: "text.badge.checkmark", isPrimary: true,
                isEnabled: !matches.isEmpty, identifier: "edit.captionFind.replaceAll"
            ) {
                viewModel.replaceAllCaptionMatches(query, with: replacement)
                focused = nil
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .cueSheetChrome()
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .onAppear { focused = .find }
        .accessibilityIdentifier("edit.captionFind")
    }

    // MARK: - Fields

    private func field(
        _ label: String, text: Binding<String>, prompt: String, systemImage: String, field: Field, identifier: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            // The prompt in `ink2`, as `SearchField`: `inkHint` is 4.3:1 on the field's fill over the sheet.
            TextField(label, text: text, prompt: Text(prompt).foregroundStyle(Palette.ink2))
                .font(.system(.body))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(field == .find ? .next : .done)
                .focused($focused, equals: field)
                .onSubmit { focused = field == .find ? .replace : nil }
                .accessibilityLabel(Text(label))
                .accessibilityIdentifier(identifier)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.leading, 12)
        .frame(minHeight: Metrics.hitTarget)
        .background(Palette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(focused == field ? Palette.acc : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Results

    @ViewBuilder
    private func summary(_ matches: [CaptionFindReplace.Match]) -> some View {
        let cleaned = CaptionFindReplace.cleaned(query)
        Group {
            if cleaned.isEmpty {
                Text("Type a word to find it in every line.")
            } else if matches.isEmpty {
                Text("No line says “\(cleaned)”")
            } else {
                Text("\(matches.count) matches")
            }
        }
        .font(.system(.footnote, weight: .semibold))
        .foregroundStyle(Palette.ink2)
        .accessibilityIdentifier("edit.captionFind.summary")
    }

    private func row(_ match: CaptionFindReplace.Match) -> some View {
        HStack(spacing: 10) {
            Button {
                focused = nil
                if let line = viewModel.captionListLines.first(where: { $0.cueID == match.cueID }) {
                    viewModel.pickCaptionLine(line.cueID, at: line.line.start)
                }
            } label: {
                marked(match)
                    .font(.system(.subheadline))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Shows this line in the video"))
            Button {
                viewModel.replaceCaptionMatch(match, query: query, with: replacement)
            } label: {
                Text("Replace")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(Palette.fill, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit.captionFind.replace.\(match.id)")
        }
        .padding(.vertical, 2)
    }

    /// The line around the match, the match itself in yellow and bold; long lines are shortened before it so it shows.
    private func marked(_ match: CaptionFindReplace.Match) -> Text {
        let before = match.before.count > 28 ? "…" + match.before.suffix(26) : match.before
        var line = AttributedString(before)
        line.foregroundColor = Palette.ink2
        var found = AttributedString(match.found)
        found.foregroundColor = Palette.accText
        found.font = .system(.subheadline, weight: .bold)
        var after = AttributedString(match.after)
        after.foregroundColor = Palette.ink2
        line.append(found)
        line.append(after)
        return Text(line)
    }
}
