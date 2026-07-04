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
    /// - Parameter directory: 探索の基点ディレクトリ（省略時はプロセスのカレントディレクトリ）
    static func loadDefault(in directory: String = FileManager.default.currentDirectoryPath) throws -> KuraConfig {
        let candidates = [".kura.yml", ".kura.yaml", ".arkana.yml"]
        for candidate in candidates {
            let path = (directory as NSString).appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: path) {
                return try load(from: path)
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
        guard isValidModuleName(importName) else {
            throw KuraError.invalidConfig(
                "'import_name' must be a valid Swift module name (got '\(importName)')"
            )
        }

        let resultPath: String = try optionalValue(yaml, key: "result_path") ?? "."

        // 生成物は独立した SwiftPM パッケージなので、internal だとアプリ側から参照できない。
        // デフォルトは public とし、生成ソースをアプリターゲットへ直接取り込む場合のみ internal を選べるようにする
        let swiftDecl: String = try optionalValue(yaml, key: "swift_declaration") ?? "public"
        guard swiftDecl == "internal" || swiftDecl == "public" else {
            throw KuraError.invalidConfig(
                "'swift_declaration' must be 'internal' or 'public' (got '\(swiftDecl)')"
            )
        }

        let globalKeys: [String] = try optionalValue(yaml, key: "global_secrets") ?? []

        let rawEnvs: [String: Any] = try optionalValue(yaml, key: "environments") ?? [:]
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

    /// キーが存在すれば期待する型で返し、型が違えばエラーにする
    /// （型不一致を黙ってデフォルト値に落とすと、シークレット0件のまま成功してしまう）
    private static func optionalValue<T>(_ yaml: [String: Any], key: String) throws -> T? {
        guard let raw = yaml[key], !(raw is NSNull) else { return nil }
        guard let typed = raw as? T else {
            throw KuraError.invalidConfig("'\(key)' has an unexpected type in .kura.yml")
        }
        return typed
    }

    /// Swiftモジュール名として妥当か（英字/アンダースコア始まり、英数字/アンダースコアのみ）
    private static func isValidModuleName(_ name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
