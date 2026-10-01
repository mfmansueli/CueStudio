//
//  EditorPanelContainer.swift
//  Cue Studio
//

import SwiftUI

/// Every panel's frame: the title and, under it, what the panel changes ("This clip", "Whole
/// take", "Applies to all 8 lines"); Reset when it makes sense; and the yellow ✓ that applies and
/// closes. Under the header, optional fixed rows (a field, a scope, tabs), then the content, which
/// scrolls when it doesn't fit (large text, a short screen).
struct EditorPanelContainer<Fixed: View, Content: View>: View {
    let title: String
    let subtitle: String
    var onReset: (() -> Void)?
    let onApply: () -> Void
    @ViewBuilder var fixed: Fixed
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            header
            fixed
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: Metrics.editorPanelRadius, topTrailingRadius: Metrics.editorPanelRadius, style: .continuous)
                .fill(Palette.editorPanel)
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: Metrics.editorPanelRadius, topTrailingRadius: Metrics.editorPanelRadius, style: .continuous)
                        .strokeBorder(Palette.editorSeparator, lineWidth: 0.5)
                        .mask(alignment: .top) { Rectangle().frame(height: Metrics.editorPanelRadius + 1) }
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityIdentifier("edit.panel.subtitle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onReset {
                Button("Reset", action: onReset)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("edit.panel.reset")
            }
            Button {
                Haptics.apply()
                onApply()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.accInk)
                    .frame(width: Metrics.applyButtonSize, height: Metrics.applyButtonSize)
                    .background(Palette.acc, in: Circle())
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Apply"))
            .accessibilityIdentifier("edit.panel.apply")
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .frame(height: 56)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

extension EditorPanelContainer where Fixed == EmptyView {
    init(title: String, subtitle: String, onReset: (() -> Void)? = nil, onApply: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, onReset: onReset, onApply: onApply, fixed: { EmptyView() }, content: content)
    }
}
