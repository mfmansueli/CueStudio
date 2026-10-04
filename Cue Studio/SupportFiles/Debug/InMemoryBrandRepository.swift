//
//  InMemoryBrandRepository.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Keeps the brands in memory, for previews and UI tests.
final class InMemoryBrandRepository: BrandRepository {
    private var brands: [BrandBrief]

    init(brands: [BrandBrief] = []) { self.brands = brands }

    func load() throws -> [BrandBrief] { brands }

    func save(_ brands: [BrandBrief]) throws { self.brands = brands }
}
#endif
