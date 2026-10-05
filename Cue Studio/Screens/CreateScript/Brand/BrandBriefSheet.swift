//
//  BrandBriefSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Sponsored ad · Brand brief" (v29 · B): what the ad may say. Saved brands as chips ("+ New brand"), the brand and the
/// product (required), what it must say and never say, a link and a code; "Paid partnership · #ad" is always on; and
/// "✦ Write the ad", which the AI writes from this brief and nothing else. Without Apple Intelligence (or for a
/// draft you write yourself) the button opens the draft instead, and nothing is violet.
struct BrandBriefSheet: View {
    let purpose: BrandBriefPurpose
    let canWriteWithAI: Bool
    let onConfirm: (BrandBrief) -> Void

    @State private var model: BrandBriefViewModel
    @Environment(ToastService.self) private var toast
    @Environment(\.dismiss) private var dismiss

    init(store: BrandStore, purpose: BrandBriefPurpose, canWriteWithAI: Bool, onConfirm: @escaping (BrandBrief) -> Void) {
        self.purpose = purpose
        self.canWriteWithAI = canWriteWithAI
        self.onConfirm = onConfirm
        _model = State(initialValue: BrandBriefViewModel(store: store))
    }

    private var writesAd: Bool { purpose == .writeFromCard && canWriteWithAI }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.blockGap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sponsored ad · Brand brief")
                        .font(CueStudioFont.hud).textCase(.uppercase).tracking(1.2)
                        .foregroundStyle(Palette.accText)
                    Text("What may the ad say?")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !model.savedBrands.isEmpty { savedBrands }
                field("Brand", text: $model.draft.name, prompt: String(localized: "e.g. Oat & Co."), id: "name")
                field("Product or offer", text: $model.draft.product, prompt: String(localized: "e.g. Barista oat milk"), id: "product")
                field("Must say", text: $model.draft.mustSay, prompt: String(localized: "Key claims the brand approved"), id: "mustSay")
                field(
                    "Never say", text: $model.draft.neverSay, prompt: String(localized: "e.g. health claims, competitor names"),
                    id: "neverSay"
                )
                HStack(spacing: 10) {
                    field("Link", text: $model.draft.link, prompt: "oatandco.com/maya", id: "link")
                    field("Code", text: $model.draft.code, prompt: "MAYA10", id: "code")
                }
                options
                Button(action: confirm) {
                    HStack(spacing: 6) {
                        if writesAd { Image(systemName: "sparkles") }
                        Text(writesAd ? "Write the ad" : "Open the draft")
                    }
                }
                .buttonStyle(.cuePrimary(.large))
                .opacity(model.canWrite ? 1 : 0.4)
                .accessibilityIdentifier("brandBrief.confirm")
                Text("Cue uses only this. Nothing is invented.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity)
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 28, trailing: Metrics.gutter))
        }
        .scrollDismissesKeyboard(.interactively)
        .cueSheetChrome()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("brandBrief.sheet")
    }

    // MARK: - Pieces

    private var savedBrands: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.savedBrands) { brand in
                    Button { model.select(brand) } label: {
                        FilterChip(label: brand.name, isSelected: model.selectedBrandID == brand.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("brandBrief.brand.\(brand.name)")
                }
                Button { model.startNew() } label: {
                    FilterChip(label: String(localized: "+ New brand"), isSelected: false)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("brandBrief.newBrand")
            }
        }
        .scrollIndicators(.hidden)
    }

    private func field(
        _ title: LocalizedStringKey, text: Binding<String>, prompt: String, id: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
            TextField("", text: text, prompt: Text(verbatim: prompt).foregroundStyle(Palette.inkHint))
                .font(.system(size: 15))
                .foregroundStyle(Palette.ink)
                .tint(Palette.accText)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                .accessibilityLabel(Text(title))
                .accessibilityIdentifier("brandBrief.\(id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Paid partnership · #ad" is always on (no switch), and "Save brand" keeps the brief for the next ad.
    private var options: some View {
        @Bindable var model = model
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(verbatim: "AD")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.adTagInk)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Palette.adTagFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paid partnership label").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text("Adds #ad to your caption").font(.footnote).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 8)
                Text("Always on")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).textCase(.uppercase)
                    .foregroundStyle(Palette.successText)
            }
            .padding(14)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("brandBrief.partnership")
            Divider().overlay(Palette.separator)
            Toggle("Save brand", isOn: $model.savesBrand)
                .font(.subheadline.weight(.semibold))
                .tint(Palette.success)
                .padding(.horizontal, 14)
                .frame(minHeight: Metrics.hitTarget + 6)
                .accessibilityIdentifier("brandBrief.saveBrand")
        }
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
    }

    private func confirm() {
        guard let brief = model.commit() else {
            toast.show(String(localized: "Add brand and product"))
            return
        }
        onConfirm(brief)
    }
}
