import Foundation
import Yams

/// .kura.yml の内容を表す型
struct KuraConfig {
    /// 生成するSwiftモジュール名（import_name）
    let importName: String
    /// 出力先ディレクトリ（result_path）
    let resultPath: String
    /// 暗号化する環境変数名の一覧（global_secrets）
    let globalSecrets: [String]
    /// 環境ごとの環境変数名（environments: [env_name: [key]]）
    let environments: [String: [String]]
    /// Swiftのアクセス修飾子（"internal" / "public"）
    let swiftDeclaration: String

    /// 設定ファイルを読み込んでパースする
    /// .kura.yml → .arkana.yml の順で探索する（後方互換）
    static func load(from path: String) throws -> KuraConfig {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        guard let yaml = try Yams.load(yaml: content) as? [String: Any] else {
            throw KuraError.invalidConfig("Failed to parse \(path) as YAML dictionary")
        }
        return try parse(yaml)
    }

    /// デフォルトの設定ファイルパスを探索して読み込む
    static func loadDefault() throws -> KuraConfig {
        let candidates = [".kura.yml", ".kura.yaml", ".arkana.yml"]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return try load(from: candidate)
            }
        }
        throw KuraError.invalidConfig(
            "No config file found. Looked for: \(candidates.joined(separator: ", "))"
        )
    }

    // MARK: - Private

    private static func parse(_ yaml: [String: Any]) throws -> KuraConfig {
        guard let importName = yaml["import_name"] as? String else {
            throw KuraError.invalidConfig("'import_name' is required in .kura.yml")
        }
        let resultPath = yaml["result_path"] as? String ?? "."
        let swiftDecl = yaml["swift_declaration"] as? String ?? "internal"
        let globalKeys = yaml["global_secrets"] as? [String] ?? []
        let rawEnvs = yaml["environments"] as? [String: Any] ?? [:]

        var environments: [String: [String]] = [:]
        for (envName, value) in rawEnvs {
            guard let keys = value as? [String] else {
                throw KuraError.invalidConfig("'environments.\(envName)' must be a list of strings")
            }
            environments[envName] = keys
        }

        return KuraConfig(
            importName: importName,
            resultPath: resultPath,
            globalSecrets: globalKeys,
            environments: environments,
            swiftDeclaration: swiftDecl
        )
    }
}
