import Testing
import Foundation
@testable import KuraGenerator

struct KuraEncoderTests {

    /// エンコード実装内部の xor と同じロジックで復号する（プライベートAPIのため呼び出し側で再実装）
    private func xorDecrypt(_ encoded: [UInt8], salt: [UInt8]) -> String {
        let bytes = encoded.enumerated().map { idx, byte -> UInt8 in
            byte ^ salt[idx % salt.count]
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    @Test func encodeDecodeRoundTrip() {
        let encoder = KuraEncoder()
        let secret = "super-secret-value-123"

        let encoded = encoder.encode(secret)
        let decoded = xorDecrypt(encoded.encodedBytes, salt: encoded.salt)

        #expect(decoded == secret)
    }

    @Test func saltHasConfiguredLength() {
        let encoder = KuraEncoder(saltLength: 16)
        let encoded = encoder.encode("value")

        #expect(encoded.salt.count == 16)
    }

    @Test func encodedBytesLengthMatchesSecretLength() {
        let encoder = KuraEncoder()
        let secret = "hello"

        let encoded = encoder.encode(secret)

        #expect(encoded.encodedBytes.count == secret.utf8.count)
    }

    @Test func differentCallsProduceDifferentSalts() {
        let encoder = KuraEncoder()
        let first = encoder.encode("same-value")
        let second = encoder.encode("same-value")

        #expect(first.salt != second.salt)
    }

    @Test func byteLiteralFormat() {
        let encoder = KuraEncoder(saltLength: 1)
        let encoded = encoder.encode("")

        #expect(encoded.saltLiteral.hasPrefix("[0x"))
        #expect(encoded.saltLiteral.hasSuffix("]"))
        #expect(encoded.encodedBytesLiteral == "[]")
    }
}
