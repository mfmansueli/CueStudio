//
//  CueTabBar.swift
//  Cue Studio
//

import SwiftUI

/// The v29 tab bar: real Liquid Glass (`glassEffect(.regular.interactive())` in a capsule), 64 pt high, with the five tabs
/// at 26 pt and 10 pt labels. The active tab sits in a 56 pt glass capsule inset 4 pt that slides to the chosen
/// tab with a 0.32 s spring (a fade with Reduce Motion). Record is 30 pt, a thin ring with a solid red dot, and opens
/// "Start recording" without becoming the selected tab. It is a tab bar for VoiceOver and for UI tests.
struct CueTabBar: View {
    let selection: AppTab
    let onSelect: (AppTab) -> Void

    @Namespace private var capsuleSpace
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
        .padding(Metrics.tabCapsuleInset)
        .frame(height: Metrics.tabBarHeight)
        .background(Palette.glassBarBase, in: Capsule())
        .glassEffect(.regular.interactive(), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.glassBarRim, lineWidth: 0.5))
        .shadow(color: Palette.glassBarShadow, radius: 15, y: 10)
        .padding(.horizontal, Metrics.tabBarSideMargin)
        .animation(CueMotion.animation(CueMotion.tabCapsule, reduced: reduceMotion), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tabBar")
    }

    private func button(for item: Item) -> some View {
        let isActive = item.tab == selection && item.tab != .record
        // Not a `Button`: SwiftUI exposes a button with a stacked label as several elements, and this
        // is one tab, so one element with the button trait.
        return VStack(spacing: 3) {
            Group {
                if let icon = item.icon {
                    CueIconView(icon, size: Metrics.tabIconSize)
                } else {
                    RecordGlyph()
                }
            }
            .frame(height: Metrics.tabRecordSize)
            Text(item.title)
                .font(.system(size: Metrics.tabLabelSize, weight: isActive ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(isActive ? Palette.accText : Palette.ink2)
        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
        .frame(height: Metrics.tabCapsuleHeight)
        .background {
            if isActive {
                activeCapsule.matchedGeometryEffect(id: "capsule", in: capsuleSpace)
            }
        }
        .contentShape(Capsule())
        .onTapGesture {
            Haptics.selection()
            onSelect(item.tab)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("tab.\(String(describing: item.tab))")
    }

    /// The active tab's glass: white 16% → 6%, a 0.5 pt edge and a light along the top.
    private var activeCapsule: some View {
        Capsule()
            .fill(Palette.tabCapsuleFill)
            .overlay(Capsule().strokeBorder(Palette.tabCapsuleBorder, lineWidth: 0.5))
            .overlay(alignment: .top) {
                Capsule().fill(Palette.tabCapsuleHighlight).frame(height: 1).padding(.horizontal, 16).padding(.top, 0.5)
            }
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
