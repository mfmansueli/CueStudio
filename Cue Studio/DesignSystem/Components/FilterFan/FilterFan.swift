//
//  FilterFan.swift
//  Cue Studio
//

import SwiftUI

/// A row of filter chips that folds into the chosen one (Scripts and Takes, the owner's idea, 05/11/2026; `DESIGN_PROJECT.md` §2 and §6.2).
///
/// Folded, the row shows the chosen chip and a dot for each hidden option (`FilterFanPeek`). A tap on it unfolds the others out from
/// behind it, the nearest first, with a light tick of the Taptic Engine as each comes free; a tap on one picks it and folds the rest back
/// into it, which moves to the start of the row, with a firm tap as the last lands. A tap on the chosen chip, outside the row or a scroll of
/// the list (`View.foldsFilterFan`) folds it without a change. Under the chips the fill is one liquid (`FilterFanLiquid`): a neck joins a
/// chip to the one it leaves until it breaks. The order of the chips never changes.
///
/// It never folds with fewer than three options, nor under VoiceOver or Switch Control (`FilterFanPlan.folds`): there it is the row of
/// always, chips side by side. Each screen draws its chips' insides (`chip`: the dot, the name, a count) in the ink the chosen state asks
/// for; the fan draws the capsules.
struct FilterFan<Option: Hashable, Chip: View, Leading: View>: View {
    let options: [Option]
    @Binding var selection: Option
    @Binding var state: FilterFanState
    var chipHeight: CGFloat
    var peekColor: (Option) -> Color
    var identifier: (Option) -> String
    var label: (Option) -> String
    var value: (Option) -> String? = { _ in nil }
    var menu: (Option) -> FilterFanMenu? = { _ in nil }
    /// The chosen chip's capsule: the app's white, or Find inspiration's violet (its ideas are the AI's).
    var selectedFill: Color = Palette.chipOn
    /// Room kept at the row's end for a control laid over it that never folds (Find inspiration's "Topics"): no chip is wider than what is
    /// left, and the open row scrolls past it.
    var trailingInset: CGFloat = 0
    /// What comes before the fan and never folds (Takes' "2026 · SHARED ✕").
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var chip: (Option, Bool) -> Chip

    @State private var widths: [Option: CGFloat] = [:]
    @State private var rowWidth: CGFloat = 0
    @State private var leadingWidth: CGFloat = 0
    @State private var pressed: Option?
    @State private var scroll = ScrollPosition(edge: .leading)
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControl
    @Environment(\.scenePhase) private var scenePhase

    private var folds: Bool {
        FilterFanPlan.folds(optionCount: options.count, assistiveTechnology: voiceOver || switchControl)
    }

    private var plan: FilterFanPlan {
        FilterFanPlan(
            widths: options.map { min(widths[$0] ?? 0, boxWidth) },
            selected: options.firstIndex(of: selection) ?? 0,
            isOpen: state.isOpen || !folds
        )
    }

    private var boxWidth: CGFloat {
        // Before the row has a width, room enough for any name: never a cut name in the first frame.
        guard rowWidth > 0 else { return 600 }
        return FilterFanPlan.maxChipWidth(
            rowWidth: rowWidth - trailingInset, gutter: Metrics.gutter, leadingWidth: leadingWidth > 0 ? leadingWidth + 8 : 0, hasPeek: folds
        )
    }

    var body: some View {
        let plan = plan
        ScrollView(.horizontal) {
            // No spacing of the stack's own: an absent `leading` (nil, or Scripts' none) takes none, and one that is there gets its 8 pt.
            HStack(spacing: 0) {
                leading()
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { leadingWidth = $0 })
                fan(plan)
                    .padding(.leading, leadingWidth > 0 ? 8 : 0)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.trailing, trailingInset)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        // Folded, nothing to scroll to: the open row's width stays, so a fold that starts scrolled never jumps.
        .scrollDisabled(!plan.isOpen)
        .scrollPosition($scroll)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }, action: { frame in
            if rowWidth > 0, frame.width != rowWidth { state.isOpen = false }
            rowWidth = frame.width
            state.frame = frame
        })
        .onChange(of: selection) { _, _ in state.isOpen = false }
        .onChange(of: folds) { _, _ in state.isOpen = false }
        .onChange(of: state.isOpen) { _, isOpen in
            guard !isOpen else { return }
            withAnimation(FilterFanMotion.fold) { scroll.scrollTo(edge: .leading) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { state.isOpen = false }
        }
        .onDisappear { state.isOpen = false }
    }

    private func fan(_ plan: FilterFanPlan) -> some View {
        ZStack(alignment: .leading) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                chipButton(option, at: index, plan: plan)
            }
            if folds {
                FilterFanPeek(plan: plan, colors: plan.peekIndices.map { peekColor(options[$0]) })
            }
        }
        .frame(width: max(plan.openWidth, 1), height: Metrics.hitTarget, alignment: .leading)
        .background(alignment: .topLeading) { measures }
        .background(alignment: .leading) {
            FilterFanLiquid(plan: plan, chipHeight: chipHeight, boxWidth: boxWidth, pressed: pressed.flatMap { options.firstIndex(of: $0) })
        }
    }

    /// Each chip's width, read from a still, hidden copy of the chips: read from the moving ones, a name in Arabic measured one width, then
    /// another, at every frame, and the row never settled.
    private var measures: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.self) { option in
                // Its whole width, then no wider than the box (the chip there cuts the name with "…"): asked of the box, the hidden copy
                // in a sheet kept the width of a first, narrow layout (Find inspiration, 05/11/2026).
                chip(option, option == selection)
                    .fixedSize()
                    .frame(height: chipHeight)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width in
                        if abs((widths[option] ?? 0) - width) > 0.5 { widths[option] = width }
                    })
                    .frame(width: boxWidth, alignment: .leading)
            }
        }
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func chipButton(_ option: Option, at index: Int, plan: FilterFanPlan) -> some View {
        let isSelected = option == selection
        let isShown = plan.placement(at: index).isShown
        return Button { tap(option, plan: plan) } label: {
            chip(option, isSelected)
                .frame(height: chipHeight)
                .background(isSelected ? selectedFill : .clear, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Capsule())
        }
        .buttonStyle(FanPressStyle { isDown in pressed = isDown ? option : (pressed == option ? nil : pressed) })
        .modifier(MenuOnChip(menu: menu(option)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label(option)))
        .accessibilityValue(Text(value(option) ?? ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier(option))
        .accessibilityHidden(!isShown)
        .allowsHitTesting(isShown)
        .modifier(FilterFanPlacing(index: index, plan: plan, layer: .chip, boxWidth: boxWidth))
    }

    private func tap(_ option: Option, plan: FilterFanPlan) {
        guard folds else {
            guard option != selection else { return }
            Haptics.selection()
            selection = option
            return
        }
        if !state.isOpen {
            var open = plan
            open.isOpen = true
            HapticPatterns.playFanUnfold(releases: open.releaseTimes)
            state.isOpen = true
        } else if option == selection {
            Haptics.soft()
            state.isOpen = false
        } else {
            var folded = plan
            folded.isOpen = false
            folded.selected = options.firstIndex(of: option) ?? plan.selected
            HapticPatterns.playFanFold(landing: folded.foldLanding)
            // One change, so the pick and the fold are one movement.
            selection = option
            state.isOpen = false
        }
    }
}

extension FilterFan {
    /// The press of a chip (`PressResponse`), told to the fan too, so the chip's fill in the liquid sinks with its label.
    private struct FanPressStyle: ButtonStyle {
        let onPress: (Bool) -> Void

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .pressResponse(configuration.isPressed, depth: PressResponse.compactDepth)
                .onChange(of: configuration.isPressed) { _, isPressed in onPress(isPressed) }
        }
    }

    /// The chip's one action, held or among VoiceOver's actions.
    private struct MenuOnChip: ViewModifier {
        let menu: FilterFanMenu?

        func body(content: Content) -> some View {
            if let menu {
                content
                    .contextMenu {
                        Button(menu.title, systemImage: menu.systemImage, role: .destructive, action: menu.action)
                            .accessibilityIdentifier(menu.identifier)
                    }
                    .accessibilityAction(named: Text(menu.title), menu.action)
            } else {
                content
            }
        }
    }
}

extension FilterFan where Leading == EmptyView {
    init(
        options: [Option], selection: Binding<Option>, state: Binding<FilterFanState>, chipHeight: CGFloat,
        peekColor: @escaping (Option) -> Color, identifier: @escaping (Option) -> String, label: @escaping (Option) -> String,
        value: @escaping (Option) -> String? = { _ in nil }, menu: @escaping (Option) -> FilterFanMenu? = { _ in nil },
        selectedFill: Color = Palette.chipOn, trailingInset: CGFloat = 0, @ViewBuilder chip: @escaping (Option, Bool) -> Chip
    ) {
        self.init(
            options: options, selection: selection, state: state, chipHeight: chipHeight, peekColor: peekColor, identifier: identifier,
            label: label, value: value, menu: menu, selectedFill: selectedFill, trailingInset: trailingInset, leading: { EmptyView() }, chip: chip
        )
    }
}
