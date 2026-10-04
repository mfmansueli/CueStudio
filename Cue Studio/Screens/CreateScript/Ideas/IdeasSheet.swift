//
//  IdeasSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Need an idea?" (S2c): ideas from the creator's topics. ↑ writes one into a new script; a tap
/// on the idea itself puts it on the card, to change before it is written.
struct IdeasSheet: View {
    @State private var viewModel: IdeasViewModel
    let onEdit: (ThemeIdea) -> Void
    let onWrite: (ThemeIdea) -> Void

    @Environment(\.dismiss) private var dismiss

    init(services: AppServices, onEdit: @escaping (ThemeIdea) -> Void, onWrite: @escaping (ThemeIdea) -> Void) {
        _viewModel = State(initialValue: IdeasViewModel(
            writer: services.writer, profile: services.profile, toast: services.toast,
            interfaceLanguage: services.languages.interfaceLanguage
        ))
        self.onEdit = onEdit
        self.onWrite = onWrite
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("✦ From your topics")
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Palette.aiText)
                SheetHeader(title: String(localized: "Need an idea?"), onClose: { dismiss() })
            }
            topics
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.ideas) { idea in
                        IdeaRow(
                            idea: idea, canWrite: viewModel.canWrite,
                            onEdit: { dismiss(); onEdit(idea) },
                            onWrite: { dismiss(); onWrite(idea) }
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            footer
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ideas.sheet")
    }

    /// "All topics" and one chip per topic the creator works in.
    private var topics: some View {
        @Bindable var viewModel = viewModel
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button { viewModel.topic = nil } label: {
                    FilterChip(label: String(localized: "All topics"), isSelected: viewModel.topic == nil)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ideas.topic.all")
                ForEach(viewModel.topics) { niche in
                    Button { viewModel.topic = niche } label: {
                        FilterChip(label: niche.label, isSelected: viewModel.topic == niche)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ideas.topic.\(niche.rawValue)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.loadNewIdeas() }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isLoading {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("More ideas")
                }
            }
            .buttonStyle(.cueSecondary(.compact, expands: false))
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("ideas.moreButton")
            Text("Tap an idea to edit it first, or ↑ to write it as is.")
                .font(.caption)
                .foregroundStyle(Palette.ink2)
        }
    }
}
