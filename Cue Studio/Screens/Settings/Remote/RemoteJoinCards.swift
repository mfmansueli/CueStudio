//
//  RemoteJoinCards.swift
//  Cue Studio
//

import SwiftUI

/// "Use this iPhone as a remote": two cards side by side, Enter a code and Scan the code, each with its icon on a yellow tile (the
/// family of what a creator records with, `SettingsIcon`) and what it asks for. They sink under the finger like the app's cards.
struct RemoteJoinCards: View {
    @State private var isEnteringCode = false
    @State private var isScanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CueSectionHeader("Use this iPhone as a remote")
                .padding(.horizontal, Metrics.textGutter)
            HStack(spacing: 10) {
                card("keyboard", String(localized: "Enter a code"), String(localized: "The six letters on the teleprompter"), id: "settings.enterCode") {
                    isEnteringCode = true
                }
                card("qrcode.viewfinder", String(localized: "Scan the code"), String(localized: "Point the camera at the QR code"), id: "settings.scanCode") {
                    isScanning = true
                }
            }
        }
        .remoteJoinFlow(isEnteringCode: $isEnteringCode, isScanning: $isScanning)
    }

    private func card(_ symbol: String, _ title: String, _ detail: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.Settings.toolGlyph)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(colors: [Palette.Settings.toolTileTop, Palette.Settings.toolTileBottom], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        }
        .buttonStyle(.cuePressCard)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(id)
    }
}
