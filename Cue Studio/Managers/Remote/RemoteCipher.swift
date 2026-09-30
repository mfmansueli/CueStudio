//
//  RemoteCipher.swift
//  Cue Studio
//

import CryptoKit
import Foundation

/// What the pairing code becomes on the link: the name the teleprompter is found by and the key
/// that seals every frame. The code itself never goes over the air, and a device without it can
/// neither read nor send anything. The code is short (six letters), so this keeps nearby devices
/// out; it is not meant to resist someone recording the traffic and guessing codes offline.
nonisolated struct RemoteCipher: Sendable {
    /// The Bonjour name the teleprompter advertises: a hash of the code, not the code.
    let serviceName: String
    private let key: SymmetricKey

    init(code: String) {
        key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(code.utf8)),
            salt: Data("studio.cue.remote".utf8),
            info: Data("frames".utf8),
            outputByteCount: 32
        )
        let digest = SHA256.hash(data: Data("studio.cue.remote.service/\(code)".utf8))
        serviceName = "Cue " + digest.prefix(6).map { String(format: "%02x", $0) }.joined()
    }

    func seal(_ plain: Data) throws -> Data {
        guard let sealed = try AES.GCM.seal(plain, using: key).combined else {
            throw CryptoKitError.incorrectParameterSize
        }
        return sealed
    }

    /// Throws when `sealed` wasn't sealed with the same code, or was changed on the way.
    func open(_ sealed: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key)
    }
}
