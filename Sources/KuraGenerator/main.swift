import Foundation

// MARK: - 引数パース

// 使い方:
//   kura-generator [--config <path>] [--dotenv <path>] [--output <path>]
//
// デフォルト値:
//   --config  .kura.yml（なければ .arkana.yml にフォールバック）
//   --dotenv  .env
//   --output  .kura.yml の result_path を使用

func argument(for flag: String, default defaultValue: String? = nil) -> String? {
    let args = CommandLine.arguments
    if let idx = args.firstIndex(of: flag), args.index(after: idx) < args.endIndex {
        return args[args.index(after: idx)]
    }
    return defaultValue
}

let dotenvPath = argument(for: "--dotenv", default: ".env")
let outputPath = argument(for: "--output")

// MARK: - メイン処理

do {
    // 1. 設定ファイルを読み込む
    let config: KuraConfig
    if let configPath = argument(for: "--config") {
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
