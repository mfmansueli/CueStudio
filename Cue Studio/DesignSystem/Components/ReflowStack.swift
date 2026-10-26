//
//  ReflowStack.swift
//  Cue Studio
//

import SwiftUI

/// Side by side at the standard text sizes, one above the other at the accessibility sizes, as the system's own rows do: a picture and
/// its words side by side left the words room for a word a line (`InterfaceType`).
struct ReflowStack<Content: View>: View {
    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat?
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
        layout { content }
    }
}
