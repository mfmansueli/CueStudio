//
//  BrandBriefViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("BrandBriefViewModel")
struct BrandBriefViewModelTests {
    private func makeStore(_ brands: [BrandBrief] = []) -> BrandStore {
        let store = BrandStore(repository: InMemoryBrandRepository(brands: brands))
        store.load()
        return store
    }

    private let oat = BrandBrief(name: "Oat & Co.", product: "Barista oat milk", mustSay: "Froths like dairy", code: "MAYA10")

    @Test func startsEmptyAndCannotWriteYet() {
        let model = BrandBriefViewModel(store: makeStore())
        #expect(!model.canWrite)
        #expect(model.commit() == nil)
        #expect(model.savedBrands.isEmpty)
    }

    @Test func theBrandUsedLastFillsTheFields() {
        let model = BrandBriefViewModel(store: makeStore([oat, BrandBrief(name: "Lumen", product: "Desk lamp")]))
        #expect(model.draft.name == "Oat & Co.")
        #expect(model.canWrite)
        #expect(model.selectedBrandID == oat.id)
    }

    @Test func aBrandAndAProductAreRequired() {
        let model = BrandBriefViewModel(store: makeStore())
        model.draft.name = "Oat & Co."
        #expect(!model.canWrite)
        model.draft.product = "  "
        #expect(!model.canWrite)
        model.draft.product = "Barista oat milk"
        #expect(model.canWrite)
    }

    @Test func newBrandClearsTheFieldsAndPickingBringsThemBack() {
        let model = BrandBriefViewModel(store: makeStore([oat]))
        model.startNew()
        #expect(model.draft == BrandBrief(id: model.draft.id))
        #expect(model.selectedBrandID == nil)
        model.select(oat)
        #expect(model.draft.mustSay == "Froths like dairy")
    }

    @Test func committingSavesTheBrandOnlyWhenAskedTo() {
        let store = makeStore()
        let model = BrandBriefViewModel(store: store)
        model.draft = oat
        model.savesBrand = false
        #expect(model.commit()?.name == "Oat & Co.")
        #expect(store.brands.isEmpty)
        model.savesBrand = true
        _ = model.commit()
        #expect(store.brands.map(\.name) == ["Oat & Co."])
    }
}
