//
//  ScriptReadView.swift
//  Cue Studio
//

import SwiftUI

/// Read mode: the script, under a title and one line about its length. Everything else is one tap
/// away: "Improve script" for the AI tools, the summary line for the details, any paragraph to
/// start writing there.
struct ScriptReadView: View {
    let viewModel: ScriptDetailViewModel
    let script: Script
    let onStudio: () -> Void
    let onRecord: () -> Void
    let onOpenTake: (Take) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    ImproveScriptButton(hasTip: viewModel.hookOverrun != nil) { viewModel.sheet = .improve }
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.top, 12)
                    if viewModel.needsFactCheck {
                        FactCheckBanner(onChecked: viewModel.markFactChecked)
                            .padding(.horizontal, Metrics.gutter)
                            .padding(.top, 10)
                    }
                    paragraphs
                    if !viewModel.scriptTakes.isEmpty {
                        takesSection
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            // A block picked in the details: the reader goes there.
            .onChange(of: viewModel.readScrollTarget) { _, target in
                guard let target else { return }
                viewModel.readScrollTarget = nil
                withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(target, anchor: .top) }
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(script.displayTitle)
                .font(.title.bold())
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ScriptSummaryRow(platform: script.platform, zone: viewModel.zone) { viewModel.sheet = .details }
        }
        .padding(.horizontal, Metrics.textGutter)
        .padding(.top, 8)
    }

    private var paragraphs: some View {
        let blocks = viewModel.blocks
        let summaries = viewModel.summaries
        return VStack(alignment: .leading, spacing: 18) {
            if script.isEmpty {
                Text("This script is empty. Tap to start writing.")
                    .font(.body)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.startEditing() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("detail.emptyText")
            }
            ForEach(blocks) { block in
                ScriptParagraphView(
                    block: block,
                    isLongHook: block.index == 0 && viewModel.hookOverrun != nil,
                    blockSeconds: summaries.first { $0.firstParagraph == block.index }?.seconds,
                    onEdit: { viewModel.startEditing(atParagraph: block.index) }
                )
                .id(block.index)
            }
            if !script.isEmpty {
                Text("Tap any line to edit")
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, Metrics.textGutter)
        .padding(.top, 24)
    }

    private var takesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Takes").font(.title3.bold())
                Spacer()
                Text("\(viewModel.scriptTakes.count) takes · v\(script.version)")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            .padding(.horizontal, Metrics.textGutter)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(viewModel.scriptTakes) { take in
                        Button { onOpenTake(take) } label: {
                            TakeTile(take: take, width: 96, height: 170)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 28)
    }

    private var actionBar: some View {
        let prefersStudio = viewModel.preset.prefersStudio
        return HStack(spacing: 10) {
            Button(action: onStudio) {
                Label("Studio mode", systemImage: "text.alignleft")
            }
            .buttonStyle(CueStudioButtonStyle(variant: prefersStudio ? .primary : .secondary, size: .large))
            .accessibilityIdentifier("detail.studioButton")
            Button(action: onRecord) {
                Label("Record", systemImage: "video.fill")
            }
            .buttonStyle(CueStudioButtonStyle(variant: prefersStudio ? .secondary : .primary, size: .large))
            .accessibilityIdentifier("detail.recordButton")
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background {
            LinearGradient(colors: [Palette.bg.opacity(0), Palette.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.4))
                .ignoresSafeArea()
        }
    }
}
