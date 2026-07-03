import Foundation

/// .env ファイルと ProcessInfo の環境変数をマージして返す
struct EnvLoader {
    /// dotenv ファイルのパス（nil の場合はファイル読み込みをスキップ）
    let dotenvPath: String?

    /// キーの一覧に対して値を解決する
    /// 優先順位: 環境変数（CI）> .env ファイル
    func resolve(keys: [String]) throws -> [String: String] {
        let fileValues = try loadFile()
        let envValues = ProcessInfo.processInfo.environment

        var result: [String: String] = [:]
        for key in keys {
            if let v = envValues[key] {
                // CI 上では環境変数から取得
                result[key] = v
            } else if let v = fileValues[key] {
                result[key] = v
            } else {
                throw KuraError.missingSecret(key)
            }
        }
        return result
    }

    // MARK: - Private

    private func loadFile() throws -> [String: String] {
        guard let path = dotenvPath,
              FileManager.default.fileExists(atPath: path) else { return [:] }
        let content = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        return parse(content)
    }

    /// dotenv 形式を解析する
    /// 対応形式:
    ///   KEY=value
    ///   KEY="value with spaces"
    ///   KEY='value'
    ///   # comment
    ///   export KEY=value
    private func parse(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in content.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)

            // コメント・空行をスキップ
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            // `export KEY=value` 形式に対応
            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count))
            }

            guard let eqRange = line.range(of: "=") else { continue }
            let key = String(line[..<eqRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            var value = String(line[eqRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            // クォートを取り除く
            let isQuoted = (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                (value.hasPrefix("'") && value.hasSuffix("'"))
            if isQuoted {
                value = String(value.dropFirst().dropLast())
            } else if let commentIdx = value.firstIndex(of: "#") {
                // クォートされた値はリテラル扱いとし、インラインコメント除去の対象外にする
                // （例: KEY="p#ssw0rd" が "p" に切り詰められるのを防ぐ）
                value = String(value[..<commentIdx])
                    .trimmingCharacters(in: .whitespaces)
            }

            guard !key.isEmpty else { continue }
            result[key] = value
        }
        return result
    }
}
