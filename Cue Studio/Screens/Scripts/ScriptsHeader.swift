//
//  ScriptsHeader.swift
//  Cue Studio
//

import SwiftUI

/// The top of Scripts as on the board (3.2): the title with its yellow mono count ("8 SCRIPTS · 3 READY") under it, and three
/// 40 pt round buttons — Logbook (violet, with the number of ideas waiting), Search and New script.
struct ScriptsHeader: View {
    let summaryValues: [String]
    var summaryTint: Color = Palette.accText
    let logbookCount: Int
    var showsLogbook = true
    var showsSearch = true
    let onLogbook: () -> Void
    let onSearch: () -> Void
    let onNew: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scripts")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.68)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                HUDLine(values: summaryValues, tint: summaryTint)
                    .accessibilityIdentifier("scripts.summary")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsLogbook { logbookButton }
            if showsSearch { roundButton(systemImage: "magnifyingglass", label: "Search", id: "scripts.searchButton", action: onSearch) }
            roundButton(systemImage: "plus", label: "New script", id: "scripts.newButton", action: onNew)
        }
        .padding(.top, 2)
    }

    private var logbookButton: some View {
        Button(action: onLogbook) {
            CueIconView(.logbook, size: 18)
                .foregroundStyle(Palette.aiTextStrong)
                .frame(width: 40, height: 40)
                .background(Palette.aiFill, in: Circle())
                .overlay(alignment: .topTrailing) {
                    if logbookCount > 0 {
                        Text(verbatim: "\(logbookCount)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.bg)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Palette.aiText, in: Capsule())
                            .offset(x: 2, y: -2)
                    }
                }
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Logbook"))
        .accessibilityValue(Text(logbookCount > 0 ? "\(logbookCount)" : ""))
        .accessibilityIdentifier("scripts.logbookButton")
    }

    private func roundButton(systemImage: String, label: LocalizedStringKey, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(width: 40, height: 40)
                .background(Palette.fill, in: Circle())
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }
}
