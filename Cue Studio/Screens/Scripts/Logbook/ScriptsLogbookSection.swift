//
//  ScriptsLogbookSection.swift
//  Cue Studio
//

import SwiftUI

/// The end of the Scripts list (v30 · 3.2): the ideas still waiting in the Logbook, up to two, each with "✦ Write" (which turns it into a script,
/// "Write it" without Apple Intelligence), and "Open Logbook ›". Nothing shows when no idea is waiting. While Scripts selects, the ideas are
/// picked like the scripts above them (their mark in place of ✦ Write, a tap picks or lets go) and deleted with them; held, an idea offers
/// Delete.
struct ScriptsLogbookSection: View {
    /// What Scripts has picked, while it selects; nil otherwise.
    var selection: Set<UUID>?
    var onToggle: (UUID) -> Void = { _ in }
    var onDelete: (LogbookEntry) -> Void = { _ in }

    @Environment(LogbookService.self) private var logbook
    @Environment(AIStatus.self) private var aiStatus
    @Environment(ScriptStarter.self) private var starter
    @Environment(IdeaTransitionService.self) private var transition
    @Environment(PresentationService.self) private var presentation

    private static let visibleLimit = 2

    var body: some View {
        let waiting = logbook.waiting
        if !waiting.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // As plain as the groups' titles above it (`ScriptsView.groupHeader`), in the Logbook's violet.
                Text("Logbook")
                    .cueFont(15, weight: .semibold)
                    .foregroundStyle(Palette.aiText)
                    .padding(.horizontal, 12)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(waiting.prefix(Self.visibleLimit))) { entry in
                        if let selection {
                            selectableRow(entry, isSelected: selection.contains(entry.id))
                        } else {
                            row(entry)
                        }
                    }
                    if selection == nil {
                        Button { presentation.present(.logbook) } label: {
                            Text("Open Logbook ›")
                                .cueFont(14.5, weight: .semibold)
                                .foregroundStyle(Palette.inkSoft)
                                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("scripts.logbook.open")
                    }
                }
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                .cardDepth(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("scripts.logbook")
        }
    }

    private func ideaText(_ entry: LogbookEntry) -> some View {
        Text(entry.text)
            .cueFont(15)
            .foregroundStyle(Palette.ink)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// While selecting: the whole row picks the idea, its mark where ✦ Write was.
    private func selectableRow(_ entry: LogbookEntry, isSelected: Bool) -> some View {
        Button {
            Haptics.selection()
            onToggle(entry.id)
        } label: {
            HStack(spacing: 10) {
                ideaText(entry)
                ScriptSelectionMark(isSelected: isSelected)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 14) }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("scripts.logbook.idea")
    }

    private func row(_ entry: LogbookEntry) -> some View {
        HStack(spacing: 10) {
            ideaText(entry)
            Button { write(entry) } label: {
                Text(aiStatus.isAvailable ? "✦ Write" : "Write it")
                    .cueFont(14, weight: .semibold)
                    .foregroundStyle(aiStatus.isAvailable ? Palette.aiTextStrong : Palette.accText)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(aiStatus.isAvailable ? Palette.aiFill : Palette.accSoft, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(transition.isActive)
            .accessibilityIdentifier("scripts.logbook.write")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 14) }
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) { onDelete(entry) } label: { Label("Delete", systemImage: "trash") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scripts.logbook.idea")
    }

    /// Like the Logbook's own "✦ Write": the star makes the idea a script (the idea leaves the Logbook once it has).
    private func write(_ entry: LogbookEntry) {
        if aiStatus.isAvailable {
            Haptics.medium()
            starter.write(idea: entry.text) { [logbook] scriptID in logbook.markShaped(entry.id, as: scriptID) }
        } else {
            logbook.markShaped(entry.id, as: starter.writeByHand(idea: entry.text))
        }
    }
}
