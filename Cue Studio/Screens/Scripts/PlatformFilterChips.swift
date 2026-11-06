//
//  PlatformFilterChips.swift
//  Cue Studio
//

import SwiftUI

/// The filters of Scripts, platform first ("All 14 · TikTok 7 · Reels 4 · Shorts 3"), then any folders, in a row that folds into the chosen
/// one (`FilterFan`). The chosen one is the white chip. A folder's chip, held, deletes the folder (its scripts stay).
struct PlatformFilterChips: View {
    let filters: [ScriptFilter]
    @Binding var selection: ScriptFilter
    @Binding var fan: FilterFanState
    let count: (ScriptFilter) -> Int
    let deleteFolder: (String) -> Void

    var body: some View {
        FilterFan(
            options: filters, selection: $selection, state: $fan, chipHeight: 34,
            peekColor: \.peekColor, identifier: { "scripts.filter.\($0.identifier)" }, label: \.label, value: { "\(count($0))" },
            menu: menu(for:),
            chip: { filter, isSelected in chip(filter, isSelected: isSelected) }
        )
        .accessibilityIdentifier("scripts.filters")
    }

    /// 14 / 600; the dot (7 pt) after 10 pt of padding, the count in mono 11 (the chosen one has black text). A long folder name is cut
    /// with "…", never the count.
    private func chip(_ filter: ScriptFilter, isSelected: Bool) -> some View {
        var hasLeading = true
        if case .all = filter { hasLeading = false }
        return HStack(spacing: 6) {
            switch filter {
            case .platform(let platform): PlatformDot(color: platform.tint)
            case .folder: Image(systemName: "folder").cueFont(12, weight: .semibold)
            case .all: EmptyView()
            }
            Text(filter.label)
                .truncationMode(.tail)
            Text(verbatim: "\(count(filter))")
                .monoFont(size: 11)
                .foregroundStyle(isSelected ? Palette.inkOnLight : Palette.ink2)
                .fixedSize()
        }
        .cueFont(14, weight: .semibold)
        .lineLimit(1)
        .padding(.leading, hasLeading ? 10 : 14)
        .padding(.trailing, hasLeading ? 12 : 14)
        .foregroundStyle(isSelected ? Palette.chipOnInk : Palette.ink)
    }

    /// Delete folder, on a folder's chip only: held, or among VoiceOver's actions.
    private func menu(for filter: ScriptFilter) -> FilterFanMenu? {
        guard case .folder(let name) = filter else { return nil }
        return FilterFanMenu(title: "Delete folder", systemImage: "trash", identifier: "scripts.filter.deleteFolder") { deleteFolder(name) }
    }
}

extension ScriptFilter {
    /// The id of the filter's chip (`scripts.filter.<identifier>`).
    var identifier: String {
        switch self {
        case .all: "all"
        case .platform(let platform): platform.rawValue
        case .folder(let name): "folder.\(name)"
        }
    }

    /// Its dot after the folded row (`FilterFanPeek`): a network's colour, a folder's grey, All's white.
    var peekColor: Color {
        switch self {
        case .all: Palette.ink
        case .platform(let platform): platform.tint
        case .folder: Palette.ink3
        }
    }
}
