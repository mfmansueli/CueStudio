//
//  CleanUpCardRow.swift
//  Cue Studio
//

import SwiftUI

/// A sideways row of Clean up's cards (`CleanUpCard`), sized so the next one always peeks in at the edge when there are more
/// than fit (Remove counts them all).
struct CleanUpCardRow: View {
    @Bindable var viewModel: QuickEditViewModel
    let suggestions: [CleanUpSuggestion]
    /// "pause" or "word": the cards are `edit.<kind>.<index>`.
    let kind: String

    /// The narrowest a card gets; it grows with the text size.
    @ScaledMetric(relativeTo: .caption) private var cardMinimum: CGFloat = 104
    /// The width of the row (the panel's), measured.
    @State private var rowWidth: CGFloat = 0

    /// How much of the next card shows at the edge.
    private static let peek: CGFloat = 0.35
    private static let cardSpacing: CGFloat = 8
    private static let rowInset: CGFloat = 16

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                cards
                    // Room for the lit card's ring (`CleanUpCard.isHighlighted`).
                    .padding(.vertical, 5)
                    .padding(.horizontal, Self.rowInset)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.clips.highlightedCleanUpID, initial: true) { _, id in
                // A mark tapped on the timeline brings its card into view (canvas 2 M3).
                guard let id, suggestions.contains(where: { $0.id == id }) else { return }
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .padding(.horizontal, -Self.rowInset)
    }

    private var cards: some View {
            HStack(spacing: Self.cardSpacing) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    CleanUpCard(
                        title: suggestion.kind == .pause ? viewModel.clips.cardLength(suggestion) : suggestion.title,
                        time: viewModel.clips.cardTime(suggestion),
                        isMarked: viewModel.clips.isMarked(suggestion),
                        isListening: viewModel.clips.listeningID == suggestion.id,
                        isHighlighted: viewModel.clips.highlightedCleanUpID == suggestion.id,
                        identifier: "edit.\(kind).\(index)",
                        width: cardWidth,
                        onToggle: { viewModel.clips.tapCleanUpCard(suggestion.id) },
                        onListen: { viewModel.clips.listen(to: suggestion.id) }
                    )
                    .id(suggestion.id)
                }
            }
    }

    /// A card's width for a row `length` wide: as many whole cards as fit at the minimum, plus a part of the next one.
    static func cardWidth(in length: CGFloat, minimum: CGFloat) -> CGFloat {
        let room = max(0, length - rowInset)
        let whole = max(1, ((room - peek * minimum) / (minimum + cardSpacing)).rounded(.down))
        return max(minimum, (room - whole * cardSpacing) / (whole + peek))
    }

    private var cardWidth: CGFloat { rowWidth > 0 ? Self.cardWidth(in: rowWidth, minimum: cardMinimum) : cardMinimum }
}
