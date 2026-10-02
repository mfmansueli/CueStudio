//
//  EditorPhotoPicker.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// The editor's one photo picker. Panels and toolbar buttons ask for a photo (`PhotoRequest`) and
/// never present the library themselves: the system picker is shown from the root of the editor,
/// a standard sheet that lays itself out inside the device's safe areas, instead of from views
/// that live in a panel, a timeline overlay or another sheet.
struct EditorPhotoPicker: ViewModifier {
    let viewModel: QuickEditViewModel

    @State private var isPresented = false
    @State private var picked: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $picked, matching: viewModel.photoRequest?.filter ?? .images, photoLibrary: .shared())
            .onChange(of: viewModel.photoRequest) { _, request in
                isPresented = request != nil
            }
            .onChange(of: picked) { _, item in
                guard let item else { return }
                picked = nil
                Task { await viewModel.importPickedPhoto(item) }
            }
    }
}

extension View {
    func editorPhotoPicker(_ viewModel: QuickEditViewModel) -> some View {
        modifier(EditorPhotoPicker(viewModel: viewModel))
    }
}
