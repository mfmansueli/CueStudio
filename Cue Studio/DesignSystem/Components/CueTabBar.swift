//
//  CueTabBar.swift
//  Cue Studio
//

import SwiftUI

/// The v27 tab bar: a floating glass pill with the five v2 icons. Resting tabs are 62% white, the active
/// one is yellow, and a 6 pt yellow orb under its label **travels** to the tab that is chosen, with a
/// little overshoot. Record keeps its ring with a red orb and opens "Start recording" without becoming
/// the selected tab. It is a tab bar for VoiceOver and for UI tests (`.isTabBar`).
struct CueTabBar: View {
    let selection: AppTab
    let onSelect: (AppTab) -> Void

    @Namespace private var orbSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Item: Identifiable {
        let tab: AppTab
        let icon: CueIcon?
        let title: LocalizedStringKey
        var id: AppTab { tab }
    }

    private let items = [
        Item(tab: .scripts, icon: .scripts, title: "Scripts"),
        Item(tab: .takes, icon: .takes, title: "Takes"),
        Item(tab: .record, icon: nil, title: "Record"),
        Item(tab: .profile, icon: .profile, title: "Profile"),
        Item(tab: .settings, icon: .settings, title: "Settings"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                button(for: item)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 64)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .glassNight(in: RoundedRectangle(cornerRadius: 32, style: .continuous), density: .solid)
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabBar")
    }

    private func button(for item: Item) -> some View {
        let isActive = item.tab == selection
        // Not a `Button`: SwiftUI exposes a button with a stacked label as several elements, and this
        // is one tab, so one element with the button trait.
        return VStack(spacing: 3) {
            Group {
                if let icon = item.icon {
                    CueIconView(icon, size: 22)
                } else {
                    // Record: a ring with a red orb (a template icon can't be two colors).
                    Image(uiImage: RecordGlyph.tabImage).resizable().scaledToFit().frame(width: 22, height: 22)
                }
            }
            .foregroundStyle(isActive ? Palette.acc : Palette.ink2)
            Text(item.title)
                .font(.system(size: 10.5, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Palette.acc : Palette.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ZStack {
                Color.clear.frame(width: 6, height: 6)
                if isActive {
                    Circle()
                        .fill(Palette.acc)
                        .frame(width: 6, height: 6)
                        .shadow(color: Palette.acc, radius: 4)
                        .matchedGeometryEffect(id: "orb", in: orbSpace)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.selection()
            onSelect(item.tab)
        }
        .animation(CueMotion.animation(CueMotion.tabOrb, reduced: reduceMotion), value: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(isActive && item.tab != .record ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("tab.\(String(describing: item.tab))")
    }
}

#if DEBUG
#Preview {
    @Previewable @State var tab = AppTab.scripts
    VStack {
        Spacer()
        CueTabBar(selection: tab) { if $0 != .record { tab = $0 } }
    }
    .background(Palette.bg)
}
#endif
