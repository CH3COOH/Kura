import Testing
import Foundation
@testable import KuraGenerator

struct EnvLoaderTests {

    private func writeDotenv(_ content: String) throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("env")
            .path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test func resolvesSimpleKeyValue() throws {
        let path = try writeDotenv("API_KEY=abc123\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: ["API_KEY"])
        #expect(result["API_KEY"] == "abc123")
    }

    @Test func stripsDoubleAndSingleQuotes() throws {
        let path = try writeDotenv(
            """
            DOUBLE="hello world"
            SINGLE='hello single'
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: ["DOUBLE", "SINGLE"])
        #expect(result["DOUBLE"] == "hello world")
        #expect(result["SINGLE"] == "hello single")
    }

    @Test func supportsExportPrefix() throws {
        let path = try writeDotenv("export TOKEN=xyz\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: ["TOKEN"])
        #expect(result["TOKEN"] == "xyz")
    }

    @Test func skipsCommentsAndBlankLines() throws {
        let path = try writeDotenv(
            """
            # this is a comment

            KEY=value
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: ["KEY"])
        #expect(result["KEY"] == "value")
    }

    @Test func stripsInlineComment() throws {
        let path = try writeDotenv("KEY=value # trailing comment\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: ["KEY"])
        #expect(result["KEY"] == "value")
    }

    @Test func processEnvironmentTakesPriorityOverFile() throws {
        let key = "KURA_TEST_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        let path = try writeDotenv("\(key)=from_file\n")
        defer { try? FileManager.default.removeItem(atPath: path) }
        setenv(key, "from_env", 1)
        defer { unsetenv(key) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: [key])
        #expect(result[key] == "from_env")
    }

    @Test func doesNotTruncateQuotedValueContainingHash() throws {
        let path = try writeDotenv("PASSWORD=\"p#ssw0rd\"\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: ["PASSWORD"])
        #expect(result["PASSWORD"] == "p#ssw0rd")
    }

    @Test func stripsQuotesAndInlineCommentTogether() throws {
        let path = try writeDotenv("API_KEY=\"secret\" # prod key\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: ["API_KEY"])
        #expect(result["API_KEY"] == "secret")
    }

    @Test func doesNotTruncateUnquotedValueAtHashWithoutWhitespace() throws {
        let path = try writeDotenv(
            """
            PASSWORD=p#ssw0rd
            ENDPOINT=https://example.com/page#section
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = try EnvLoader(dotenvPath: path).resolve(keys: ["PASSWORD", "ENDPOINT"])
        #expect(result["PASSWORD"] == "p#ssw0rd")
        #expect(result["ENDPOINT"] == "https://example.com/page#section")
    }

    @Test func throwsWhenKeyIsMissing() throws {
        let path = try writeDotenv("OTHER_KEY=value\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            _ = try EnvLoader(dotenvPath: path).resolve(keys: ["MISSING_KEY"])
            Issue.record("Expected KuraError.missingSecret to be thrown")
        } catch KuraError.missingSecret(let key) {
            #expect(key == "MISSING_KEY")
        }
    }
}
