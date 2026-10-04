//
//  BrandStoreTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("BrandStore")
struct BrandStoreTests {
    private func brand(_ name: String, product: String = "Barista oat milk") -> BrandBrief {
        BrandBrief(name: name, product: product, mustSay: "Froths like dairy", neverSay: "Health claims", link: "oatandco.com/maya", code: "MAYA10")
    }

    @Test func aBrandNeedsABrandAndAProduct() {
        let store = BrandStore(repository: InMemoryBrandRepository())
        #expect(store.save(BrandBrief(name: "Oat & Co.")) == nil)
        #expect(store.save(BrandBrief(product: "Milk")) == nil)
        #expect(store.save(BrandBrief(name: "  ", product: "Milk")) == nil)
        #expect(store.brands.isEmpty)
        #expect(store.save(brand("Oat & Co.")) != nil)
    }

    @Test func savingTheSameBrandAgainUpdatesItAndPutsItFirst() {
        let store = BrandStore(repository: InMemoryBrandRepository())
        store.save(brand("Oat & Co."))
        store.save(brand("Lumen"))
        store.save(brand("oat & co.", product: "Barista oat milk 1 L"))
        #expect(store.brands.map(\.name) == ["oat & co.", "Lumen"])
        #expect(store.brands.first?.product == "Barista oat milk 1 L")
    }

    @Test func brandsSurviveARelaunch() {
        let repository = InMemoryBrandRepository()
        let first = BrandStore(repository: repository)
        first.save(brand("Oat & Co."))
        let second = BrandStore(repository: repository)
        second.load()
        #expect(second.brands.map(\.name) == ["Oat & Co."])
        #expect(second.brands.first?.link == "oatandco.com/maya")
    }

    @Test func aBrandCanBeRemoved() throws {
        let store = BrandStore(repository: InMemoryBrandRepository())
        let saved = try #require(store.save(brand("Oat & Co.")))
        store.remove(saved.id)
        #expect(store.brands.isEmpty)
        #expect(store.brand(id: saved.id) == nil)
    }

    @Test func theLocalRepositoryWritesJSONThatReadsBack() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "cue-brands-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalBrandRepository(directory: directory)
        #expect(try repository.load().isEmpty)
        try repository.save([brand("Oat & Co.")])
        #expect(try repository.load().map(\.name) == ["Oat & Co."])
    }
}
