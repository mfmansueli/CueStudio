//
//  QuickEditViewModel+PhotoPicker.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import _PhotosUI_SwiftUI

/// Asking for a photo: the panels and the toolbar only say what for (`PhotoRequest`), the editor
/// shows the picker once (`EditorPhotoPicker`), and the pick comes back here to be put where it was
/// asked for.
extension QuickEditViewModel {
    /// The photo or video picked for the request that opened the library.
    func importPickedPhoto(_ item: PhotosPickerItem) async {
        guard let request = photoRequest else { return }
        photoRequest = nil
        switch request.purpose {
        case .background: await look.importBackgroundImage(item)
        case .replaceMedia(let id, _): await overlays.replaceMedia(id, importing: item)
        case .replaceClip(let id): await clips.replaceClip(id, importing: item)
        }
    }
}
