import Testing
import Foundation
@testable import KuraGenerator

struct ConfigTests {

    private func writeYaml(_ content: String) throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".yml")
            .path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test func parsesFullConfig() throws {
        let path = try writeYaml(
            """
            import_name: KuraKeys
            result_path: Generated
            swift_declaration: public
            global_secrets:
              - API_KEY
              - ANALYTICS_TOKEN
            environments:
              debug:
                - DEBUG_ENDPOINT
              release:
                - RELEASE_ENDPOINT
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = try KuraConfig.load(from: path)

        #expect(config.importName == "KuraKeys")
        #expect(config.resultPath == "Generated")
        #expect(config.swiftDeclaration == "public")
        #expect(config.globalSecrets == ["API_KEY", "ANALYTICS_TOKEN"])
        #expect(config.environments["debug"] == ["DEBUG_ENDPOINT"])
        #expect(config.environments["release"] == ["RELEASE_ENDPOINT"])
    }

    @Test func appliesDefaultsWhenOptionalFieldsAreMissing() throws {
        let path = try writeYaml("import_name: KuraKeys\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = try KuraConfig.load(from: path)

        #expect(config.resultPath == ".")
        #expect(config.swiftDeclaration == "public")
        #expect(config.globalSecrets == [])
        #expect(config.environments == [:])
        #expect(config.preserveKeyCase == false)
    }

    @Test func parsesPreserveKeyCase() throws {
        let path = try writeYaml(
            """
            import_name: KuraKeys
            preserve_key_case: true
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = try KuraConfig.load(from: path)
        #expect(config.preserveKeyCase == true)
    }

    @Test func throwsWhenPreserveKeyCaseIsNotABool() throws {
        let path = try writeYaml(
            """
            import_name: KuraKeys
            preserve_key_case: yes_please
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            _ = try KuraConfig.load(from: path)
            Issue.record("Expected KuraError.invalidConfig to be thrown")
        } catch KuraError.invalidConfig {
            // expected
        }
    }

    @Test func throwsWhenImportNameIsMissing() throws {
        let path = try writeYaml("result_path: .\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            _ = try KuraConfig.load(from: path)
            Issue.record("Expected KuraError.invalidConfig to be thrown")
        } catch KuraError.invalidConfig {
            // expected
        }
    }

    @Test func throwsWhenEnvironmentValueIsNotAList() throws {
        let path = try writeYaml(
            """
            import_name: KuraKeys
            environments:
              debug: NOT_A_LIST
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            _ = try KuraConfig.load(from: path)
            Issue.record("Expected KuraError.invalidConfig to be thrown")
        } catch KuraError.invalidConfig {
            // expected
        }
    }

    @Test func loadDefaultFallsBackToArkanaYml() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "import_name: LegacyKeys\n".write(
            to: dir.appendingPathComponent(".arkana.yml"),
            atomically: true,
            encoding: .utf8
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let config = try KuraConfig.loadDefault(in: dir.path)
        #expect(config.importName == "LegacyKeys")
    }

    @Test func throwsWhenGlobalSecretsIsNotAList() throws {
        let path = try writeYaml(
            """
            import_name: KuraKeys
            global_secrets: API_KEY
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            _ = try KuraConfig.load(from: path)
            Issue.record("Expected KuraError.invalidConfig to be thrown")
        } catch KuraError.invalidConfig {
            // expected
        }
    }

    @Test func treatsNonMappingEnvironmentsAsEmpty() throws {
        // .arkana.yml では environments が文字列配列になっている場合があるため、
        // 辞書でない場合はエラーにせず空として扱う（後方互換）
        let path = try writeYaml(
            """
            import_name: KuraKeys
            environments:
              - debug
              - release
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = try KuraConfig.load(from: path)
        #expect(config.environments == [:])
    }

    @Test func throwsWhenSwiftDeclarationIsInvalid() throws {
        let path = try writeYaml(
            """
            import_name: KuraKeys
            swift_declaration: pubic
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            _ = try KuraConfig.load(from: path)
            Issue.record("Expected KuraError.invalidConfig to be thrown")
        } catch KuraError.invalidConfig {
            // expected
        }
    }

    @Test func throwsWhenImportNameIsNotAValidModuleName() throws {
        let path = try writeYaml("import_name: My Keys\n")
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            _ = try KuraConfig.load(from: path)
            Issue.record("Expected KuraError.invalidConfig to be thrown")
        } catch KuraError.invalidConfig {
            // expected
        }
    }

    @Test func treatsNullEnvironmentValueAsEmptyList() throws {
        // `debug:` のように値を省略した環境は空リストとして扱う
        let path = try writeYaml(
            """
            import_name: KuraKeys
            environments:
              debug:
              release:
                - RELEASE_ENDPOINT
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = try KuraConfig.load(from: path)
        #expect(config.environments["debug"] == [])
        #expect(config.environments["release"] == ["RELEASE_ENDPOINT"])
    }

    @Test func throwsReadErrorWhenConfigFileDoesNotExist() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".yml")
            .path

        do {
            _ = try KuraConfig.load(from: path)
            Issue.record("Expected KuraError.readError to be thrown")
        } catch KuraError.readError {
            // expected
        }
    }

    @Test func treatsNullOptionalFieldsAsAbsent() throws {
        let path = try writeYaml(
            """
            import_name: KuraKeys
            global_secrets:
            environments:
            """
        )
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = try KuraConfig.load(from: path)
        #expect(config.globalSecrets == [])
        #expect(config.environments == [:])
    }
}
