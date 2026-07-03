import Testing
import Foundation
@testable import KuraGenerator

struct CodeGeneratorTests {

    private func makeTempDir() throws -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    @Test func generatesPackageAndKeysFiles() throws {
        let config = KuraConfig(
            importName: "KuraKeys",
            resultPath: ".",
            globalSecrets: ["API_KEY"],
            environments: ["debug": ["DEBUG_ENDPOINT"]],
            swiftDeclaration: "internal"
        )
        let generator = CodeGenerator(config: config, encoder: KuraEncoder())
        let basePath = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: basePath) }

        try generator.generate(secrets: ["API_KEY": "secret", "DEBUG_ENDPOINT": "https://dev.example.com"], at: basePath)

        let packageSwiftPath = (basePath as NSString)
            .appendingPathComponent("KuraKeys/Package.swift")
        let keysSwiftPath = (basePath as NSString)
            .appendingPathComponent("KuraKeys/Sources/KuraKeys/KuraKeys.swift")

        #expect(FileManager.default.fileExists(atPath: packageSwiftPath))
        #expect(FileManager.default.fileExists(atPath: keysSwiftPath))
    }

    @Test func convertsSnakeCaseKeysToCamelCaseProperties() throws {
        let config = KuraConfig(
            importName: "KuraKeys",
            resultPath: ".",
            globalSecrets: ["API_KEY", "ANALYTICS_TOKEN"],
            environments: [:],
            swiftDeclaration: "internal"
        )
        let generator = CodeGenerator(config: config, encoder: KuraEncoder())
        let basePath = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: basePath) }

        try generator.generate(
            secrets: ["API_KEY": "a", "ANALYTICS_TOKEN": "b"],
            at: basePath
        )

        let keysSwiftPath = (basePath as NSString)
            .appendingPathComponent("KuraKeys/Sources/KuraKeys/KuraKeys.swift")
        let content = try String(contentsOfFile: keysSwiftPath, encoding: .utf8)

        #expect(content.contains("static var apiKey: String"))
        #expect(content.contains("static var analyticsToken: String"))
    }

    @Test func generatesCapitalizedEnumPerEnvironment() throws {
        let config = KuraConfig(
            importName: "KuraKeys",
            resultPath: ".",
            globalSecrets: [],
            environments: ["debug": ["DEBUG_ENDPOINT"], "release": ["RELEASE_ENDPOINT"]],
            swiftDeclaration: "internal"
        )
        let generator = CodeGenerator(config: config, encoder: KuraEncoder())
        let basePath = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: basePath) }

        try generator.generate(
            secrets: ["DEBUG_ENDPOINT": "d", "RELEASE_ENDPOINT": "r"],
            at: basePath
        )

        let keysSwiftPath = (basePath as NSString)
            .appendingPathComponent("KuraKeys/Sources/KuraKeys/KuraKeys.swift")
        let content = try String(contentsOfFile: keysSwiftPath, encoding: .utf8)

        #expect(content.contains("enum KuraKeysDebug {"))
        #expect(content.contains("enum KuraKeysRelease {"))
    }

    @Test func prefixesUnderscoreForDigitLeadingKey() throws {
        let config = KuraConfig(
            importName: "KuraKeys",
            resultPath: ".",
            globalSecrets: ["2FA_SECRET"],
            environments: [:],
            swiftDeclaration: "internal"
        )
        let generator = CodeGenerator(config: config, encoder: KuraEncoder())
        let basePath = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: basePath) }

        try generator.generate(secrets: ["2FA_SECRET": "code"], at: basePath)

        let keysSwiftPath = (basePath as NSString)
            .appendingPathComponent("KuraKeys/Sources/KuraKeys/KuraKeys.swift")
        let content = try String(contentsOfFile: keysSwiftPath, encoding: .utf8)

        #expect(content.contains("static var _2faSecret: String"))
    }

    @Test func sanitizesHyphenatedEnvironmentNameToValidEnumName() throws {
        let config = KuraConfig(
            importName: "KuraKeys",
            resultPath: ".",
            globalSecrets: [],
            environments: ["stg-jp": ["ENDPOINT"]],
            swiftDeclaration: "internal"
        )
        let generator = CodeGenerator(config: config, encoder: KuraEncoder())
        let basePath = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: basePath) }

        try generator.generate(secrets: ["ENDPOINT": "https://stg.example.jp"], at: basePath)

        let keysSwiftPath = (basePath as NSString)
            .appendingPathComponent("KuraKeys/Sources/KuraKeys/KuraKeys.swift")
        let content = try String(contentsOfFile: keysSwiftPath, encoding: .utf8)

        #expect(content.contains("enum KuraKeysStgJp {"))
    }

    @Test func skipsMissingSecretsWithoutCrashing() throws {
        let config = KuraConfig(
            importName: "KuraKeys",
            resultPath: ".",
            globalSecrets: ["MISSING_KEY"],
            environments: [:],
            swiftDeclaration: "internal"
        )
        let generator = CodeGenerator(config: config, encoder: KuraEncoder())
        let basePath = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: basePath) }

        try generator.generate(secrets: [:], at: basePath)

        let keysSwiftPath = (basePath as NSString)
            .appendingPathComponent("KuraKeys/Sources/KuraKeys/KuraKeys.swift")
        let content = try String(contentsOfFile: keysSwiftPath, encoding: .utf8)

        #expect(!content.contains("missingKey"))
    }
}
