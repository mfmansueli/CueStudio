//
//  AnswerCommentSheet.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// "Answer a comment": choose a screenshot of the comment (or paste its words), check what Cue read, and Cue writes
/// the answer in the creator's voice.
struct AnswerCommentSheet: View {
    @State private var model: AnswerCommentViewModel
    @State private var picked: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(AIStatus.self) private var aiStatus

    init(model: AnswerCommentViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHeader(
                title: model.step == .confirm ? String(localized: "Is this right?") : String(localized: "Answer a comment"),
                subtitle: model.step == .confirm
                    ? String(localized: "Check the comment before Cue writes.")
                    : String(localized: "Turn a question from your audience into a script.")
            )
            switch model.step {
            case .choose: choose
            case .reading: reading
            case .confirm: confirm
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .cueSheetChrome()
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await model.read(imageData: data) }
                picked = nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("answer.sheet")
    }

    // MARK: - Steps

    private var choose: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $picked, matching: .screenshots) {
                AnswerOptionRow(
                    title: String(localized: "Choose a screenshot"), detail: String(localized: "Cue reads the comment on this iPhone"),
                    icon: "photo.on.rectangle", primary: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("answer.pickScreenshot")
            Button { model.pasteFromClipboard() } label: {
                AnswerOptionRow(
                    title: String(localized: "Paste the comment"), detail: String(localized: "From the clipboard"),
                    icon: "doc.on.clipboard", primary: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("answer.paste")
            if let failure = model.failure {
                Text(failure).font(.footnote).foregroundStyle(Palette.warnText).accessibilityIdentifier("answer.failure")
            }
            Text("The picture is read here, never kept.")
                .font(.footnote).foregroundStyle(Palette.inkHint)
        }
    }

    private var reading: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Palette.aiText)
            Text("Reading the comment…").foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var confirm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("FROM").font(CueStudioFont.hud).tracking(1).foregroundStyle(Palette.ink2)
                TextField("@name", text: $model.author)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14).frame(height: 48)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("answer.author")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("COMMENT").font(CueStudioFont.hud).tracking(1).foregroundStyle(Palette.ink2)
                TextField("What they asked", text: $model.text, axis: .vertical)
                    .lineLimit(3...8)
                    .padding(14)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("answer.text")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("ANSWER FOR").font(CueStudioFont.hud).tracking(1).foregroundStyle(Palette.ink2)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Platform.allCases) { platform in
                        Button { model.platform = platform } label: {
                            FilterChip(label: platform.label, isSelected: model.platform == platform)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("answer.platform.\(platform.rawValue)")
                    }
                }
            }
            if aiStatus.isAvailable {
                Button { model.write(); dismiss() } label: { Text("✦ Draft my reply") }
                    .buttonStyle(.cuePrimary(.large))
                    .disabled(!model.canWrite)
                    .accessibilityIdentifier("answer.write")
            }
            // Without Apple Intelligence this is the only way, and the primary one (10.2).
            if model.offersWritingByHand {
                Button { model.writeMyself(); dismiss() } label: { Text("Write it myself") }
                    .buttonStyle(aiStatus.isAvailable ? .cueSecondary(.large) : .cuePrimary(.large))
                    .disabled(!model.canWrite)
                    .accessibilityIdentifier("answer.writeMyself")
            }
            if model.offersLogbook {
                Button { model.saveForLater(); dismiss() } label: { Text("Save to Logbook") }
                    .buttonStyle(.cueSecondary(.large))
                    .disabled(!model.canWrite)
                    .accessibilityIdentifier("answer.saveToLogbook")
            }
            Button("Choose another") { model.startOver() }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
        }
    }
}

/// A big row of the first step: an icon, what it does and a line under it.
private struct AnswerOptionRow: View {
    let title: String
    let detail: String
    let icon: String
    let primary: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        return HStack(spacing: 14) {
            Image(systemName: icon).font(.title3)
                .foregroundStyle(primary ? Palette.accText : Palette.ink)
                .frame(width: 42, height: 42)
                .background(primary ? Palette.accSoft : Palette.overlayFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                // Long words and large text wrap; they never end in "…" (German at the accessibility sizes did).
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface2, in: shape)
        .overlay(shape.strokeBorder(primary ? Palette.acc : .clear, lineWidth: 1.5))
        .contentShape(shape)
    }
}
