//
//  LibraryAssetTile.swift
//  Cue Studio
//

import SwiftUI

/// A card of the media library: the file's picture (a logo on a checkerboard, so its transparency shows), its name, what it is
/// and how long, a star when it's a favorite, its place in the pick order when picked, and "Missing" or "Can't be read" when
/// its file is gone or broken.
struct LibraryAssetTile: View {
    let asset: LibraryAsset
    let url: URL
    let status: LibraryFileReader.Status
    /// Its place in the pick order (1, 2…), nil when not picked.
    let order: Int?

    @State private var picture: UIImage?
    @ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                if asset.kind == .logo { Checkerboard() }
                if let picture {
                    Image(uiImage: picture)
                        .resizable()
                        .aspectRatio(contentMode: asset.kind == .logo ? .fit : .fill)
                        .padding(asset.kind == .logo ? 10 : 0)
                } else {
                    Image(systemName: asset.kind.systemImage)
                        .font(.title3)
                        .foregroundStyle(Palette.ink2)
                }
                if status != .ready { brokenOverlay }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Palette.fill)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            .overlay(alignment: .topLeading) { orderBadge }
            .overlay(alignment: .topTrailing) {
                if asset.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.acc)
                        .padding(6)
                        .background(Palette.Takes.durationBadge, in: Circle())
                        .padding(4)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let duration = asset.duration {
                    Text(DurationText.clock(duration))
                        .monoFont(.caption2)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Palette.Takes.durationBadge, in: Capsule())
                        .padding(5)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous)
                    .strokeBorder(order == nil ? .clear : Palette.acc, lineWidth: 3)
            }
            Text(asset.name)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Label(asset.kind.label, systemImage: asset.kind.systemImage)
                .font(.caption)
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
        }
        .task(id: asset.fileName) {
            guard status == .ready else { return }
            picture = await LibraryThumbnails.image(for: url, isVideo: asset.kind == .video, side: 240)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(order == nil ? .isButton : [.isButton, .isSelected])
    }

    private var brokenOverlay: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(status == .missing ? String(localized: "Missing") : String(localized: "Can’t be read"))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Palette.warnText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surface.opacity(0.92))
    }

    @ViewBuilder private var orderBadge: some View {
        if let order {
            Text(verbatim: "\(order)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Palette.accInk)
                .frame(width: badgeSize, height: badgeSize)
                .background(Palette.acc, in: Circle())
                .padding(5)
        }
    }

    private var accessibilityLabel: String {
        var parts = [asset.name, asset.kind.label]
        if let duration = asset.duration { parts.append(DurationText.clock(duration)) }
        if asset.isFavorite { parts.append(String(localized: "Favorite")) }
        if status == .missing { parts.append(String(localized: "Missing")) }
        if status == .unreadable { parts.append(String(localized: "Can’t be read")) }
        if let order { parts.append(String(localized: "Picked \(order)")) }
        return parts.joined(separator: ", ")
    }
}

/// Light and dark squares behind a logo, the way design apps show transparency.
private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 8
            for row in 0..<Int(ceil(size.height / square)) {
                for column in 0..<Int(ceil(size.width / square)) where (row + column).isMultiple(of: 2) {
                    let cell = CGRect(x: CGFloat(column) * square, y: CGFloat(row) * square, width: square, height: square)
                    context.fill(Path(cell), with: .color(Palette.ink3.opacity(0.35)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
