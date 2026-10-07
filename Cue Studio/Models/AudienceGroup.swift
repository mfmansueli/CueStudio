//
//  AudienceGroup.swift
//  Cue Studio
//

import Foundation

/// Who is watching (My Cue Voice · Who's watching): the audience as people, where `Vocabulary` only said which words they understand.
/// Each group implies a vocabulary, so the older field stays coherent for what still reads it.
nonisolated enum AudienceGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case teens, students, youngAdults, parents, professionals, businessOwners, localCommunity, insiders

    var id: String { rawValue }

    var label: String {
        switch self {
        case .teens: String(localized: "Teenagers")
        case .students: String(localized: "Students")
        case .youngAdults: String(localized: "Young adults")
        case .parents: String(localized: "Parents")
        case .professionals: String(localized: "Working professionals")
        case .businessOwners: String(localized: "Business owners")
        case .localCommunity: String(localized: "My local community")
        case .insiders: String(localized: "People who already know the field")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .teens: "teenagers"
        case .students: "students"
        case .youngAdults: "young adults"
        case .parents: "parents"
        case .professionals: "working professionals"
        case .businessOwners: "business owners"
        case .localCommunity: "people in the creator's local community"
        case .insiders: "people who already know the field"
        }
    }

    /// The `Vocabulary` this audience understands.
    var vocabulary: Vocabulary {
        switch self {
        case .teens, .youngAdults: .genZ
        case .professionals, .businessOwners: .professional
        case .insiders: .technical
        case .students, .parents, .localCommunity: .simple
        }
    }

    /// The groups in the order most likely for a kind of creator, so the likeliest are on top.
    static func ordered(for role: CreatorRole?) -> [AudienceGroup] {
        let first: [AudienceGroup] = switch role {
        case .personal: [.youngAdults, .parents]
        case .entertainer: [.teens, .youngAdults]
        case .expert: [.insiders, .professionals]
        case .educator: [.students, .parents]
        case .business: [.localCommunity, .businessOwners]
        case .brands: [.youngAdults, .professionals]
        case .news: [.professionals, .insiders]
        case .community: [.localCommunity, .parents]
        case nil: []
        }
        return first + allCases.filter { !first.contains($0) }
    }
}
