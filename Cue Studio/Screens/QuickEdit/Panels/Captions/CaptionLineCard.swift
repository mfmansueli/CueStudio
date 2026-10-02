//
//  CaptionLineCard.swift
//  Cue Studio
//

import SwiftUI

/// A line in Captions: when it plays ("00:05.2 → 00:07.1 · 1.9s") and what it says, yellow while
/// it plays. Picked, it opens for working line by line: the words in a field outlined in yellow
/// (Return goes on to the next line, with the keyboard still up), ‹ 3/12 › to step between lines,
/// Play and delete; More opens Start and End −/+ in tenths, Split and Join next, and opens by
/// itself on a line whose timing needs a look. A long press on any line offers Play and Delete.
struct CaptionLineCard: View {
    let viewModel: QuickEditViewModel
    let line: CaptionCue
    let cueID: UUID
    let isSelected: Bool
    let isActive: Bool
    let index: Int
    var focusesField: FocusState<Bool>.Binding

    /// The creator's choice for More; nil follows the line (open when its timing needs a look).
    @State private var moreOverride: Bool?

    private var showsMore: Bool { moreOverride ?? line.needsTimingReview }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if isSelected {
                editor
            } else {
                Text(line.text.isEmpty ? String(localized: "Empty line") : line.text)
                    .font(.system(.subheadline))
                    .foregroundStyle(isActive ? Palette.accText : (line.text.isEmpty ? Palette.ink2 : Palette.ink))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { if !isSelected { viewModel.pickCaptionLine(cueID, at: line.start) } }
        .contextMenu {
            Button("Play", systemImage: "play.fill") { viewModel.playCaptionLine(start: line.start, end: line.end) }
            Button("Delete line", systemImage: "trash", role: .destructive) { viewModel.deleteCaptionLine(cueID) }
        }
        .accessibilityElement(children: isSelected ? .contain : .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : .isButton)
        .accessibilityIdentifier("edit.captionLine.\(index)")
    }

    private var background: Color {
        if isSelected { return Palette.surface2 }
        return isActive ? Palette.accCard : Palette.panelCard
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(DurationText.editor(line.start)) → \(DurationText.editor(line.end))")
            Spacer(minLength: 4)
            if line.needsTimingReview {
                HStack(spacing: 4) {
                    Circle().fill(Palette.warn).frame(width: 6, height: 6)
                    Text("Check timing")
                }
                .foregroundStyle(Palette.warnText)
            }
            Text(verbatim: DurationText.tenths(line.end - line.start))
        }
        .font(.system(.caption).monospacedDigit())
        .foregroundStyle(isActive || isSelected ? Palette.accText : Palette.ink2)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: "What's said here"), text: Binding(
                get: { viewModel.edit.captions.first { $0.id == cueID }?.text ?? line.text },
                set: { write($0) }
            ), axis: .vertical)
            .font(.system(.subheadline))
            .lineLimit(1...4)
            .submitLabel(.next)
            .focused(focusesField)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 42)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.acc, lineWidth: 1.5))
            .accessibilityIdentifier("edit.captionField")
            HStack(spacing: 6) {
                stepper
                iconChip("play.fill", label: Text("Play"), identifier: "edit.captionPlay") {
                    viewModel.playCaptionLine(start: line.start, end: line.end)
                }
                chip(String(localized: "More"), systemImage: showsMore ? "chevron.up" : "ellipsis", identifier: "edit.captionMore") {
                    moreOverride = !showsMore
                }
                Spacer(minLength: 0)
                Button { viewModel.deleteCaptionLine(cueID) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.dangerText)
                        .frame(width: 36, height: 32)
                        .background(Palette.dangerWash, in: Capsule())
                        .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Delete line"))
                .accessibilityIdentifier("edit.captionDelete")
            }
            if showsMore {
                HStack(spacing: 8) {
                    nudger(String(localized: "Start"), edge: .start)
                    nudger(String(localized: "End"), edge: .end)
                }
                HStack(spacing: 6) {
                    chip(String(localized: "Split"), identifier: "edit.captionSplit") { viewModel.splitCaptionAtPlayhead(cueID) }
                    chip(String(localized: "Join next"), identifier: "edit.captionJoin") { viewModel.joinCaption(cueID) }
                }
            }
        }
    }

    /// Typing goes to the line; Return (a new line in the field) goes on to the next one with the
    /// keyboard still up, and at the last line puts the keyboard away.
    private func write(_ typed: String) {
        guard typed.contains("\n") else {
            viewModel.setCaptionText(cueID, typed)
            return
        }
        viewModel.setCaptionText(cueID, typed.replacingOccurrences(of: "\n", with: ""))
        if !viewModel.goToCaptionLine(from: cueID, by: 1, keepsTyping: true) { focusesField.wrappedValue = false }
    }

    /// "‹ 3/12 ›": the line before and the one after.
    private var stepper: some View {
        let position = viewModel.captionPosition(of: cueID)
        return HStack(spacing: 0) {
            stepButton("chevron.left", label: Text("Previous line"), identifier: "edit.captionPrev", step: -1)
            Text(verbatim: position.map { "\($0.number)/\($0.total)" } ?? "–")
                .font(.system(.footnote, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.ink2)
                .frame(minWidth: 36)
                .accessibilityLabel(position.map { Text("Line \($0.number) of \($0.total)") } ?? Text(verbatim: ""))
            stepButton("chevron.right", label: Text("Next line"), identifier: "edit.captionNext", step: 1)
        }
        .frame(height: 32)
        .background(Palette.fill, in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
    }

    private func stepButton(_ symbol: String, label: Text, identifier: String, step: Int) -> some View {
        let isAvailable = viewModel.neighborCaptionLine(of: cueID, by: step) != nil
        return Button {
            viewModel.goToCaptionLine(from: cueID, by: step, keepsTyping: focusesField.wrappedValue)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 32)
                .opacity(isAvailable ? 1 : 0.35)
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    /// "Start − +": a tenth earlier or later, never over a neighbor.
    private func nudger(_ label: String, edge: TrimHandle) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(.footnote))
                .foregroundStyle(Palette.ink.opacity(0.7))
            Spacer(minLength: 4)
            nudge("minus", label: edge == .start ? Text("Start earlier") : Text("End earlier"),
                  identifier: "edit.caption\(edge == .start ? "Start" : "End").minus") {
                viewModel.nudgeCaptionLine(cueID, edge: edge, by: -0.1)
            }
            nudge("plus", label: edge == .start ? Text("Start later") : Text("End later"),
                  identifier: "edit.caption\(edge == .start ? "Start" : "End").plus") {
                viewModel.nudgeCaptionLine(cueID, edge: edge, by: 0.1)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .frame(height: Metrics.hitTarget)
        .background(Palette.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func nudge(_ symbol: String, label: Text, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 38, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func chip(_ label: String, systemImage: String? = nil, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .bold)) }
                Text(label).font(.system(.footnote, weight: .semibold)).lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func iconChip(_ symbol: String, label: Text, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 40, height: 32)
                .background(Palette.fill, in: Capsule())
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
