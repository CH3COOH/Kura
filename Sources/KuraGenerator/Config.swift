import Foundation
import Yams

/// .kura.yml の内容を表す型
struct KuraConfig {
    /// 生成するSwiftモジュール名（import_name、省略時は "KuraKeys"）
    let importName: String
    /// 出力先ディレクトリ（result_path）
    let resultPath: String
    /// 暗号化する環境変数名の一覧（global_secrets）
    let globalSecrets: [String]
    /// 環境ごとの環境変数名（environments: [env_name: [key]]）
    let environments: [String: [String]]
    /// Swiftのアクセス修飾子（"internal" / "public"）
    let swiftDeclaration: String
    /// true の場合、キー名をcamelCaseに変換せずそのままプロパティ名として使う（preserve_key_case）
    let preserveKeyCase: Bool

    init(
        importName: String,
        resultPath: String,
        globalSecrets: [String],
        environments: [String: [String]],
        swiftDeclaration: String,
        preserveKeyCase: Bool = false
    ) {
        self.importName = importName
        self.resultPath = resultPath
        self.globalSecrets = globalSecrets
        self.environments = environments
        self.swiftDeclaration = swiftDeclaration
        self.preserveKeyCase = preserveKeyCase
    }

    /// 設定ファイルを読み込んでパースする
    /// .kura.yml → .arkana.yml の順で探索する（後方互換）
    static func load(from path: String) throws -> KuraConfig {
        guard FileManager.default.fileExists(atPath: path) else {
            throw KuraError.readError("Config file not found at '\(path)'")
        }
        let content: String
        do {
            content = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        } catch {
            throw KuraError.readError("Failed to read '\(path)': \(error.localizedDescription)")
        }
        guard let yaml = try Yams.load(yaml: content) as? [String: Any] else {
            throw KuraError.invalidConfig("Failed to parse \(path) as YAML dictionary")
        }
        return try parse(yaml, path: path)
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

    private static func parse(_ yaml: [String: Any], path: String) throws -> KuraConfig {
        let importName: String = try optionalValue(yaml, key: "import_name", path: path) ?? "KuraKeys"
        guard isValidModuleName(importName) else {
            throw KuraError.invalidConfig(
                "'import_name' must be a valid Swift module name (got '\(importName)')"
            )
        }

        let resultPath: String = try optionalValue(yaml, key: "result_path", path: path) ?? "."

        // 生成物は独立した SwiftPM パッケージなので、internal だとアプリ側から参照できない。
        // デフォルトは public とし、生成ソースをアプリターゲットへ直接取り込む場合のみ internal を選べるようにする
        let swiftDecl: String = try optionalValue(yaml, key: "swift_declaration", path: path) ?? "public"
        guard swiftDecl == "internal" || swiftDecl == "public" else {
            throw KuraError.invalidConfig(
                "'swift_declaration' must be 'internal' or 'public' (got '\(swiftDecl)')"
            )
        }

        let globalKeys: [String] = try optionalValue(yaml, key: "global_secrets", path: path) ?? []

        let preserveKeyCase: Bool = try optionalValue(yaml, key: "preserve_key_case", path: path) ?? false

        // .arkana.yml では environments が文字列配列（環境名のリスト）になっている場合があるため、
        // 辞書でない場合は空として扱う
        let rawEnvs: [String: Any]
        if let raw = yaml["environments"], !(raw is NSNull), let dict = raw as? [String: Any] {
            rawEnvs = dict
        } else {
            rawEnvs = [:]
        }
        var environments: [String: [String]] = [:]
        for (envName, value) in rawEnvs {
            // `debug:` のように値を省略した環境は NSNull になるため、空リストとして扱う
            if value is NSNull {
                environments[envName] = []
                continue
            }
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
            swiftDeclaration: swiftDecl,
            preserveKeyCase: preserveKeyCase
        )
    }

    /// キーが存在すれば期待する型で返し、型が違えばエラーにする
    /// （型不一致を黙ってデフォルト値に落とすと、シークレット0件のまま成功してしまう）
    private static func optionalValue<T>(_ yaml: [String: Any], key: String, path: String) throws -> T? {
        guard let raw = yaml[key], !(raw is NSNull) else { return nil }
        guard let typed = raw as? T else {
            throw KuraError.invalidConfig("'\(key)' has an unexpected type in \(path)")
        }
        return typed
    }

    /// Swiftモジュール名として妥当か（英字/アンダースコア始まり、英数字/アンダースコアのみ）
    private static func isValidModuleName(_ name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
