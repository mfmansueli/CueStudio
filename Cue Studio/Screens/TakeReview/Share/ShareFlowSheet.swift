//
//  ShareFlowSheet.swift
//  Cue Studio
//

import SwiftUI

/// The one sheet of "Share to universe" (8.1): its content follows `flow.step`, so going from the networks to the explanation to a network's step is a
/// change of content, not a sheet leaving and another coming. The ✕ and a swipe down leave the rest of the queue for later.
struct ShareFlowPresentations: ViewModifier {
    @Bindable var flow: ShareFlow
    @Bindable var review: TakeReviewViewModel
    @State private var fitted: CGFloat = 460

    func body(content: Content) -> some View {
        content
            .onChange(of: flow.step) { old, new in if old != nil, new != nil { Haptics.selection() } }
            .sheet(isPresented: Binding(get: { flow.step != nil }, set: { if !$0 { leave() } })) {
                sheetContent
                    .cueSheetChrome()
                    .presentationDetents(detents)
                    .presentationBackground(Palette.sheetNight)
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(false)
                    .modifier(ExportPresentations(viewModel: review, isActive: true))
            }
    }

    /// The networks fill the sheet; every step after them is as tall as its content (the board's sheets are), and scrolls only when it can't fit.
    @ViewBuilder
    private var sheetContent: some View {
        if flow.step == .picker {
            stepView
        } else {
            ScrollView {
                stepView
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fitted = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var stepView: some View {
        Group {
            switch flow.step {
            case .picker?:
                if let take = review.take { ShareNetworkPicker(flow: flow, review: review, take: take) }
            case .explainer?:
                ShareQueueExplainer(networks: flow.queue?.items.map(\.network) ?? []) { flow.finishExplainer() }
            case .step(let network)?:
                if let queue = flow.queue { ShareQueueStep(flow: flow, queue: queue, network: network, hasCaptions: flow.video?.hasCaptions ?? false) }
            case .confirm(let network)?:
                if let queue = flow.queue { ShareQueueConfirm(flow: flow, queue: queue, network: network) }
            case nil:
                Color.clear
            }
        }
        .id(flow.step?.id)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.25), value: flow.step)
    }

    private var detents: Set<PresentationDetent> {
        flow.step == .picker ? [.large] : [.height(min(fitted + Metrics.sheetBarHeight, 760)), .large]
    }

    private func leave() {
        if flow.step == .picker || flow.queue == nil { flow.step = nil } else { flow.close() }
    }
}
