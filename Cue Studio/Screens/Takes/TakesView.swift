//
//  TakesView.swift
//  Cue Studio
//

import SwiftUI

/// Every take, grouped by the script it was read from.
struct TakesView: View {
    @Environment(TakeLibraryService.self) private var takes
    @Environment(PresentationService.self) private var presentation
    @Environment(ToastService.self) private var toast
    @State private var takeToDelete: Take?

    var body: some View {
        let groups = TakeGroup.groups(from: takes.takes)
        Group {
            if groups.isEmpty {
                ContentUnavailableView {
                    Label("No takes yet", systemImage: "film.stack")
                } description: {
                    Text("Your recordings show up here, grouped by script.")
                } actions: {
                    Button("Record a take") { presentation.present(.newScript) }
                        .buttonStyle(.cuePrimary(.regular, expands: false))
                        .accessibilityIdentifier("takes.recordButton")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(groups) { group in
                            section(for: group)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Palette.bg)
        .navigationTitle("Takes")
        .navigationSubtitle(groups.isEmpty ? "" : String(localized: "Grouped by script"))
        .confirmationDialog(
            "Delete this take?",
            isPresented: Binding(get: { takeToDelete != nil }, set: { if !$0 { takeToDelete = nil } }),
            titleVisibility: .visible,
            presenting: takeToDelete
        ) { take in
            Button("Delete take", role: .destructive) {
                takes.delete(take.id)
                toast.show(String(localized: "Take deleted"))
            }
        } message: { _ in
            Text("The video is removed from Cue. Copies you saved to Photos stay there.")
        }
    }

    private func section(for group: TakeGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(group.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(group.takes.count == 1 ? String(localized: "1 take") : String(localized: "\(group.takes.count) takes"))
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            .padding(.horizontal, Metrics.textGutter)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(group.takes) { take in
                        Button { presentation.openReview(of: take) } label: {
                            TakeTile(take: take)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete take", systemImage: "trash", role: .destructive) { takeToDelete = take }
                        }
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { TakesView() }
        .previewEnvironment()
}
#endif
