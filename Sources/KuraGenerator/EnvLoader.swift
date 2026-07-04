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

            guard let eqIdx = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eqIdx])
                .trimmingCharacters(in: .whitespaces)
            let value = parseValue(String(line[line.index(after: eqIdx)...]))

            guard !key.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    /// `=` の右辺を値として解析する
    /// クォート値はリテラル扱い（閉じクォート以降のコメントは無視）、
    /// クォートなし値は「空白に続く #」以降をインラインコメントとして除去する
    private func parseValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if let quote = trimmed.first, quote == "\"" || quote == "'" {
            let body = trimmed.dropFirst()
            if let closing = body.firstIndex(of: quote) {
                // 例: KEY="secret" # comment → secret（クォート内はコメント除去の対象外）
                return String(body[..<closing])
            }
            // 閉じクォートがない場合はリテラルとして扱う
            return trimmed
        }

        // クォートなし: 値の先頭、または空白直後の # のみコメント開始とみなす
        // （KEY=p#ssw0rd を "p" に切り詰めない）
        var searchIdx = trimmed.startIndex
        while let hashIdx = trimmed[searchIdx...].firstIndex(of: "#") {
            if hashIdx == trimmed.startIndex || trimmed[trimmed.index(before: hashIdx)].isWhitespace {
                return String(trimmed[..<hashIdx]).trimmingCharacters(in: .whitespaces)
            }
            searchIdx = trimmed.index(after: hashIdx)
        }
        return trimmed
    }
}
