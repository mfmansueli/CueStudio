//
//  AddMusicSheet.swift
//  Cue Studio
//

import SwiftUI
import UniformTypeIdentifiers

/// "Add music": a sound file from Files, copied into the app and laid under the voice. The note
/// says why songs from Apple Music can't be picked (they have no readable track).
struct AddMusicSheet: View {
    let viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var picksFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: String(localized: "Add music"))
            Button { picksFile = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.isImportingMusic ? "hourglass" : "music.note")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.laneMusicInk)
                        .frame(width: 38, height: 38)
                        .background(Palette.laneMusic, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Browse Files")
                            .font(.system(size: 15, weight: .semibold))
                        Text("MP3, M4A, WAV or AIFF")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Palette.ink2)
                    }
                    Spacer()
                    if viewModel.isImportingMusic {
                        ProgressView().tint(Palette.ink)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.accText)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.panelCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isImportingMusic)
            .accessibilityIdentifier("edit.addMusicButton")
            Text("From Files. Use only music you own or have the rights to — songs from Apple Music can’t be added.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .fileImporter(isPresented: $picksFile, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            Task {
                await viewModel.importMusic(from: url)
                if viewModel.selectedMusicID != nil { dismiss() }
            }
        }
        .cueSheetChrome()
        .presentationDetents([.height(250 + Metrics.sheetBarHeight)])
        .presentationDragIndicator(.visible)
    }
}
