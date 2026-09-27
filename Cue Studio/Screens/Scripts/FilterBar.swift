//
//  FilterBar.swift
//  Cue Studio
//

import SwiftUI

/// Horizontally scrolling chips: All, each destination, then folders.
struct FilterBar: View {
    let filters: [ScriptFilter]
    @Binding var selection: ScriptFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        selection = filter
                    } label: {
                        FilterChip(
                            label: filter.label,
                            isSelected: selection == filter,
                            dotColor: dotColor(for: filter),
                            systemImage: filter.isFolder ? "folder" : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func dotColor(for filter: ScriptFilter) -> Color? {
        if case .platform(let platform) = filter { return platform.tint }
        return nil
    }
}

private extension ScriptFilter {
    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

#if DEBUG
#Preview {
    @Previewable @State var filter = ScriptFilter.all
    FilterBar(filters: [.all] + Platform.allCases.map(ScriptFilter.platform) + [.folder("Brand deals")], selection: $filter)
        .padding(.vertical)
        .background(Palette.bg)
}
#endif
