//
//  CodeCredit.swift
//  Cue Studio
//

import Foundation

/// Work by others that Cue's own code adapts, for Settings › Acknowledgements. Cue ships no third-party library: this is
/// where an idea, a formula or a model's weights came from, with the license that asks for its notice to travel with the app.
nonisolated struct CodeCredit: Identifiable, Hashable, Sendable {
    let name: String
    let license: String
    let copyright: String
    /// The license's text file in the bundle (without ".txt").
    let licenseFile: String

    var id: String { name }

    var licenseText: String {
        Bundle.main.url(forResource: licenseFile, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    static let all: [CodeCredit] = [
        CodeCredit(
            name: "GL Transitions", license: "MIT License", copyright: "Copyright (c) 2017-present gl-transitions contributors",
            licenseFile: "gl-transitions-MIT"
        ),
    ]
}
