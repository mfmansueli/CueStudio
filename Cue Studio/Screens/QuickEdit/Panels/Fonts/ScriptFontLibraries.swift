//
//  ScriptFontLibraries.swift
//  Cue Studio
//

import SwiftUI

/// The script libraries a font picker offers below its Latin families (Text style › Font, Caption style › Adjust, the cover's
/// Title): only `scripts`, those of the words being styled and of the creator's languages (`ScriptLibraryOffer`), so a creator
/// who writes only Latin sees nothing here. Picking a family downloads the weight in use; until it is here the words draw in
/// the system's face of the script.
struct ScriptFontLibraries: View {
    let scripts: [WritingScript]
    let store: FontPackStore
    let selection: TextOverlayFont?
    let weight: TextOverlayWeight
    let identifier: String
    let onSelect: (TextOverlayFont) -> Void

    var body: some View {
        if !scripts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(scripts) { script in
                    ScriptFontChips(
                        script: script, packs: store.manifest.packs(for: script), selection: selection, weight: weight,
                        state: { store.state(of: $0) }, identifier: identifier,
                        onSelect: { pack in
                            store.request(pack, weight: weight)
                            onSelect(.pack(pack.id))
                        }
                    )
                }
                if let failed = failedPack {
                    PanelNote(text: String(localized: "\(failed.family) couldn’t download. Check the connection and tap it again."), tint: Palette.warnText)
                        .accessibilityIdentifier("\(identifier).library.failed")
                }
                Text("Free fonts from Google Fonts. Each downloads the first time a video uses it.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var failedPack: FontPack? {
        scripts.lazy.flatMap { store.manifest.packs(for: $0) }.first { store.state(of: $0) == .failed }
    }
}
