//
//  ScriptReadView.swift
//  Cue Studio
//

import SwiftUI

/// Read mode: the script with its structure, length and takes. Editing is an explicit step.
struct ScriptReadView: View {
    let viewModel: ScriptDetailViewModel
    let script: Script
    let onStudio: () -> Void
    let onRecord: () -> Void
    let onOpenTake: (Take) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                LengthMeterView(zone: viewModel.zone)
                    .padding(EdgeInsets(top: 14, leading: 16, bottom: 10, trailing: 16))
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 18)
                BlockStripView(
                    summaries: viewModel.summaries,
                    isSerious: viewModel.structure.isSerious,
                    hookRunsLong: viewModel.hookOverrun != nil,
                    onHookTap: { viewModel.sheet = .hooks }
                )
                .padding(.top, 14)
                if let overrun = viewModel.hookOverrun {
                    Button {
                        viewModel.sheet = .hooks
                    } label: {
                        Label("Hook runs ~\(DurationText.short(overrun)) — aim for 3s. Tap Hook for options.", systemImage: "stopwatch")
                            .font(.footnote)
                            .foregroundStyle(Palette.warn)
                            .frame(minHeight: Metrics.hitTarget)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Metrics.textGutter)
                }
                paragraphs
                if !viewModel.scriptTakes.isEmpty {
                    takesSection
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(script.displayTitle)
                .font(.title.bold())
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ScriptMetaRow(
                platform: script.platform,
                formatLabel: viewModel.structure.label,
                preset: viewModel.preset,
                onDestination: { viewModel.sheet = .destination }
            )
        }
        .padding(.horizontal, Metrics.textGutter)
        .padding(.top, 8)
    }

    private var paragraphs: some View {
        VStack(alignment: .leading, spacing: 18) {
            if script.isEmpty {
                Text("This script is empty. Tap Edit to start writing.")
                    .font(.body)
                    .foregroundStyle(Palette.ink3)
            }
            ForEach(viewModel.blocks) { block in
                VStack(alignment: .leading, spacing: 6) {
                    if block.showsLabel {
                        Text(block.label)
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                            .kerning(0.9)
                            .foregroundStyle(block.index == 0 && viewModel.hookOverrun != nil ? Palette.warn : Palette.ink.opacity(0.45))
                    }
                    Text(CueAttributedText.make(block.text, cueFont: .caption.weight(.bold)))
                        .font(.system(size: 19))
                        .lineSpacing(6)
                        .foregroundStyle(Palette.ink.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Double-tap the text to edit")
                .font(.caption)
                .foregroundStyle(Palette.ink3)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.horizontal, Metrics.textGutter)
        .padding(.top, 24)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { viewModel.startEditing() }
        .accessibilityAction(named: Text("Edit")) { viewModel.startEditing() }
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
