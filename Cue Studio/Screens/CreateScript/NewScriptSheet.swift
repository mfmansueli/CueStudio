//
//  NewScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// "New script": write your own or import a document. The AI lives in the idea card on Scripts
/// ("Let's Cue!"), not here. Over the camera (attach mode) a blank page makes no sense, so Paste
/// takes Write's place.
struct NewScriptSheet: View {
    enum Mode { case new, attach }

    let mode: Mode
    var onWrite: () -> Void = {}
    var onPaste: () -> Void = {}
    let onImport: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: String(localized: "New script"),
                subtitle: String(localized: "Your words, your way."),
                onClose: { dismiss() }
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 16)

            VStack(spacing: 10) {
                switch mode {
                case .new:
                    row(
                        "Write my own", detail: "A blank page. Shape it later.", systemImage: "pencil.line",
                        isPrimary: true, identifier: "newScript.write", action: onWrite
                    )
                case .attach:
                    row(
                        "Paste", detail: "From clipboard", systemImage: "doc.on.clipboard",
                        isPrimary: true, identifier: "newScript.paste", action: onPaste
                    )
                }
                row(
                    "Import", detail: "Scan, photo, file or paste", systemImage: "square.and.arrow.down",
                    isPrimary: false, identifier: "newScript.import", action: onImport
                )
                if mode == .new {
                    Text("Want Cue to write it? Use the Let’s Cue card.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
            }
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
    }

    /// A full-width row: the way to write in a yellow ring and a yellow icon, the other in white.
    private func row(
        _ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String,
        isPrimary: Bool, identifier: String, action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isPrimary ? Palette.accText : Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(isPrimary ? Palette.accSoft : Palette.overlayFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.ink)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
            .background(Palette.surface2, in: shape)
            .overlay(shape.strokeBorder(isPrimary ? Palette.acc : .clear, lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        NewScriptSheet(mode: .new, onWrite: {}, onImport: {})
    }
}
#endif
