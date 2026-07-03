import Foundation

// MARK: - 引数パース

// 使い方:
//   kura-generator [--config <path>] [--dotenv <path>] [--output <path>]
//
// デフォルト値:
//   --config  .kura.yml（なければ .arkana.yml にフォールバック）
//   --dotenv  .env
//   --output  .kura.yml の result_path を使用

let knownFlags: Set<String> = ["--config", "--dotenv", "--output"]

func argument(for flag: String) throws -> String? {
    let args = CommandLine.arguments
    guard let idx = args.firstIndex(of: flag) else { return nil }
    let valueIdx = args.index(after: idx)
    guard valueIdx < args.endIndex, !args[valueIdx].hasPrefix("--") else {
        throw KuraError.invalidArguments("Missing value for \(flag)")
    }
    return args[valueIdx]
}

// MARK: - メイン処理

do {
    // 0. 引数を検証する（typo したフラグが黙って無視されるのを防ぐ）
    if let unknown = CommandLine.arguments.dropFirst()
        .first(where: { $0.hasPrefix("--") && !knownFlags.contains($0) }) {
        throw KuraError.invalidArguments(
            "Unknown option '\(unknown)'. Supported: \(knownFlags.sorted().joined(separator: ", "))"
        )
    }
    let dotenvPath = try argument(for: "--dotenv") ?? ".env"
    let outputPath = try argument(for: "--output")

    // 1. 設定ファイルを読み込む
    let config: KuraConfig
    if let configPath = try argument(for: "--config") {
        config = try KuraConfig.load(from: configPath)
    } else {
        config = try KuraConfig.loadDefault()
    }

    // 2. 必要なキーをすべて集める
    let allKeys = config.globalSecrets
        + config.environments.values.flatMap { $0 }

    // 3. .env / 環境変数からシークレットを解決する
    let loader = EnvLoader(dotenvPath: dotenvPath)
    let secrets = try loader.resolve(keys: allKeys)

    // 4. エンコード & コード生成
    let encoder = KuraEncoder()
    let generator = CodeGenerator(config: config, encoder: encoder)
    let basePath = outputPath ?? config.resultPath

    try generator.generate(secrets: secrets, at: basePath)

} catch let error as KuraError {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
} catch {
    fputs("❌  Unexpected error: \(error)\n", stderr)
    exit(1)
}
