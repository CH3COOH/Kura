import Foundation

/// シークレット文字列を XOR + salt でエンコードする
struct KuraEncoder {
    /// エンコード結果
    struct Encoded {
        let encodedBytes: [UInt8]
        let salt: [UInt8]

        /// Swift の [UInt8] リテラル文字列を返す（例: "[0x1A, 0x2B, ...]"）
        var encodedBytesLiteral: String {
            byteLiteral(encodedBytes)
        }

        var saltLiteral: String {
            byteLiteral(salt)
        }

        private func byteLiteral(_ bytes: [UInt8]) -> String {
            let hex = bytes.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            return "[\(hex)]"
        }
    }

    /// salt の長さ
    let saltLength: Int

    init(saltLength: Int = 64) {
        self.saltLength = saltLength
    }

    func encode(_ secret: String) -> Encoded {
        let secretBytes = Array(secret.utf8)
        let salt = randomSalt()
        let encoded = xor(secretBytes, with: salt)
        return Encoded(encodedBytes: encoded, salt: salt)
    }

    // MARK: - Private

    private func randomSalt() -> [UInt8] {
        (0 ..< saltLength).map { _ in UInt8.random(in: 0 ... 255) }
    }

    private func xor(_ bytes: [UInt8], with salt: [UInt8]) -> [UInt8] {
        guard !salt.isEmpty else { return bytes }
        return bytes.enumerated().map { idx, byte in
            byte ^ salt[idx % salt.count]
        }
    }
}
