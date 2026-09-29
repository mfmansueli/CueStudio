//
//  RemotePairing.swift
//  Cue Studio
//

import Foundation

/// The pairing code shown as a QR code on the teleprompter. Scanning it with the Camera on the other
/// device opens `cuestudio://remote?code=…` in Cue; typing it works too. Only the device with the
/// code is let in.
nonisolated enum RemotePairing {
    static let scheme = "cuestudio"
    static let host = "remote"
    static let codeLength = 6
    /// No 0/O or 1/I/L: the code is read off one screen and typed on another.
    static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    static func makeCode() -> String {
        var generator = SystemRandomNumberGenerator()
        return makeCode(using: &generator)
    }

    static func makeCode<Generator: RandomNumberGenerator>(using generator: inout Generator) -> String {
        String((0..<codeLength).map { _ in alphabet.randomElement(using: &generator) ?? "A" })
    }

    /// `cuestudio://remote?code=ABC234`
    static func url(for code: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url
    }

    /// The code in a scanned link. Nil for any other link.
    static func code(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme, url.host()?.lowercased() == host,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        return code(from: value)
    }

    /// A code typed by hand: case, spaces and dashes don't matter ("abc 234", "ABC-234"). Nil when
    /// it can't be one.
    static func code(from text: String) -> String? {
        let cleaned = text.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard cleaned.count == codeLength, cleaned.allSatisfy(alphabet.contains) else { return nil }
        return cleaned
    }

    /// "ABC 234", easier to read across a room.
    static func display(_ code: String) -> String {
        guard code.count == codeLength else { return code }
        return String(code.prefix(codeLength / 2)) + " " + String(code.suffix(codeLength / 2))
    }
}
