//
//  EmptyStateIcon.swift
//  Cue Studio
//

import SwiftUI

/// What the mark shows inside its ring.
enum EmptyStateIcon {
    case takes, book, star, search

    var image: some View {
        switch self {
        case .takes: Image(systemName: "play.square.stack")
        case .book: Image(systemName: "book.closed")
        case .star: Image(systemName: "sparkle")
        case .search: Image(systemName: "magnifyingglass")
        }
    }
}
