//
//  ReviewActionBar.swift
//  Cue Studio
//

import SwiftUI

/// Edit · Retake · Save · Share, as four tiles; Share (which opens "Share to") is the one primary
/// action.
struct ReviewActionBar: View {
    let runningAction: TakeReviewViewModel.ExportAction?
    var onEdit: (() -> Void)?
    let onRetake: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let onEdit {
                tile("Edit", systemImage: "slider.horizontal.3", identifier: "review.editButton", action: onEdit)
            }
            tile("Retake", systemImage: "arrow.counterclockwise", identifier: "review.retakeButton", action: onRetake)
            tile("Save", systemImage: "arrow.down.to.line", identifier: "review.saveButton", isRunning: runningAction == .save, action: onSave)
            tile("Share", systemImage: "square.and.arrow.up", identifier: "review.shareButton", isPrimary: true, isRunning: runningAction.map { if case .share = $0 { true } else { false } } ?? false, action: onShare)
        }
        .disabled(runningAction != nil)
    }

    private func tile(
        _ title: LocalizedStringKey, systemImage: String, identifier: String,
        isPrimary: Bool = false, isRunning: Bool = false, action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        return Button(action: action) {
            VStack(spacing: 4) {
                if isRunning {
                    ProgressView().tint(isPrimary ? Palette.accInk : Palette.ink)
                        .frame(height: 20)
                } else {
                    Image(systemName: systemImage).font(.system(size: 18, weight: .semibold))
                        .frame(height: 20)
                }
                Text(title).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(isPrimary ? Palette.accInk : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background {
                if isPrimary {
                    shape.fill(Palette.acc)
                } else {
                    shape.fill(.clear).glassEffect(.regular, in: shape)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
