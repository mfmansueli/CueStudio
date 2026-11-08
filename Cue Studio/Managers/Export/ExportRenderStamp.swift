//
//  ExportRenderStamp.swift
//  Cue Studio
//

import Foundation

/// What an exported file was drawn with beyond the edit itself (`ExportFingerprint`): the script families its words needed and
/// whether each was there, the imported families and the file of each, every media file it plays (by size and date), and the
/// build of Cue that drew it. A file is reused for a retry only while this is still the same: a font that arrived since, a photo
/// or a clip changed, a newer Cue, each makes it again, and a file whose stamp isn't known isn't reused.
///
/// It isn't part of the fingerprint, which says what counts as the same video for the free exports (the take, the edit and the
/// export settings): exporting again because a font hadn't arrived never costs a second export.
nonisolated enum ExportRenderStamp {
    /// The stamp of `edit` from what is asked of this iPhone: whether a script family is drawn, an imported family's file, a media
    /// file's size and date.
    static func make(
        edit: TakeEdit?, han: WritingScript, build: String,
        isDrawn: (FontPackNeed) -> Bool, customFile: (CustomFontUse) -> String?, mediaStamp: (String) -> String
    ) -> String {
        var parts = ["build:\(build)"]
        guard let edit else { return parts.joined(separator: "\n") }
        let needs = FontPackNeeds.needs(in: edit, han: han).sorted { ($0.packID, $0.weight.rawValue) < ($1.packID, $1.weight.rawValue) }
        for need in needs {
            parts.append("pack:\(need.packID)/\(need.weight.rawValue)=\(isDrawn(need) ? "drawn" : "system")")
        }
        let custom = edit.customFontUses.sorted { ($0.family, $0.weight.rawValue) < ($1.family, $1.weight.rawValue) }
        for use in custom {
            parts.append("custom:\(use.family)/\(use.weight.rawValue)=\(customFile(use) ?? "system")")
        }
        for name in edit.mediaFileNames.sorted() {
            parts.append("media:\(name)=\(mediaStamp(name))")
        }
        return parts.joined(separator: "\n")
    }

    /// How `edit` would be drawn now, on this iPhone.
    static func current(edit: TakeEdit?) -> String {
        make(
            edit: edit, han: FontPackRegistry.shared.hanReading, build: build,
            isDrawn: isDrawnNow, customFile: customFileNow, mediaStamp: mediaStamp
        )
    }

    /// How `result` was drawn: the families it reported missing in the system's face, the rest as they are now.
    static func drawn(edit: TakeEdit?, result: ExportResult) -> String {
        make(
            edit: edit, han: FontPackRegistry.shared.hanReading, build: build,
            isDrawn: { !result.unavailableFonts.contains($0) && isDrawnNow($0) },
            customFile: { result.missingCustomFamilies.contains($0.family) ? nil : customFileNow($0) },
            mediaStamp: mediaStamp
        )
    }

    // MARK: - This iPhone

    /// A family this version of Cue no longer lists can't arrive: it reads the same every time.
    private static func isDrawnNow(_ need: FontPackNeed) -> Bool {
        guard let pack = FontPackManifest.bundled.pack(need.packID) else { return false }
        return FontPackRegistry.shared.isReady(pack, pack.file(for: need.weight))
    }

    private static func customFileNow(_ use: CustomFontUse) -> String? {
        CustomFontRegistry.shared.face(of: use.family, weight: use.weight)?.fileName
    }

    /// Size and modification date (read with `FileManager`, which doesn't cache), "missing" when the file isn't there.
    static func mediaStamp(_ name: String) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: EditMediaFiles.url(for: name).path(percentEncoded: false)) else {
            return "missing"
        }
        let size = (attributes[.size] as? NSNumber)?.intValue ?? -1
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)@\(modified)"
    }

    /// The version and build of Cue: a newer renderer may draw the same edit differently.
    static var build: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "-")(\(info?["CFBundleVersion"] as? String ?? "-"))"
    }
}
