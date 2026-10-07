//
//  ScriptsLogbookSection.swift
//  Cue Studio
//

import SwiftUI

/// The end of the Scripts list (v30 · 3.2): the ideas still waiting in the Logbook, up to two, each with "✦ Write" (which turns it into a script,
/// "Write it" without Apple Intelligence), and "Open Logbook ›". Nothing shows when no idea is waiting.
struct ScriptsLogbookSection: View {
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
                Text("Logbook · \(waiting.count) waiting")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Palette.aiText)
                    .padding(.horizontal, 12)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(waiting.prefix(Self.visibleLimit))) { entry in
                        row(entry)
                    }
                    Button { presentation.present(.logbook) } label: {
                        Text("Open Logbook ›")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Palette.ink.opacity(0.75))
                            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("scripts.logbook.open")
                }
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                .cardDepth(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("scripts.logbook")
        }
    }

    private func row(_ entry: LogbookEntry) -> some View {
        HStack(spacing: 10) {
            Text(entry.text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { write(entry) } label: {
                Text(aiStatus.isAvailable ? "✦ Write" : "Write it")
                    .font(.system(size: 14, weight: .semibold))
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
