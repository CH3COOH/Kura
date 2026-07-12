import Foundation

/// コマンドライン引数を解釈して生成処理を実行する
struct KuraCLI {
    static let version = "1.0.3"

    static let usage = """
    USAGE: kura-generator [--config <path>] [--dotenv <path>] [--output <path>]

    OPTIONS:
      --config <path>   Config file path (default: .kura.yml → .kura.yaml → .arkana.yml)
      --dotenv <path>   dotenv file path (default: .env)
      --output <path>   Output directory (default: result_path in the config file)
      -h, --help        Show this help and exit
      --version         Show the version and exit
    """

    /// パース済みのコマンドラインオプション
    struct Options: Equatable {
        var configPath: String?
        var dotenvPath: String?
        var outputPath: String?
        var showHelp = false
        var showVersion = false
    }

    /// 実行ファイル名を除いた引数リスト（CommandLine.arguments.dropFirst() 相当）
    let arguments: [String]

    func run() throws {
        let options = try Self.parseOptions(arguments)

        if options.showHelp {
            print(Self.usage)
            return
        }
        if options.showVersion {
            print(Self.version)
            return
        }

        // 1. 設定ファイルを読み込む
        let config: KuraConfig
        if let configPath = options.configPath {
            config = try KuraConfig.load(from: configPath)
        } else {
            config = try KuraConfig.loadDefault()
        }

        // 2. 必要なキーをすべて集める
        let allKeys = config.globalSecrets
            + config.environments.values.flatMap { $0 }

        // 3. .env / 環境変数からシークレットを解決する
        //    --dotenv で明示指定されたパスは、タイポを黙って無視しないよう存在を必須にする
        let loader = EnvLoader(
            dotenvPath: options.dotenvPath ?? ".env",
            requireDotenvFile: options.dotenvPath != nil
        )
        let secrets = try loader.resolve(keys: allKeys)

        // 4. エンコード & コード生成
        let encoder = KuraEncoder()
        let generator = CodeGenerator(config: config, encoder: encoder)
        let basePath = options.outputPath ?? config.resultPath

        try generator.generate(secrets: secrets, at: basePath)
    }

    /// 引数リストをオプションに変換する
    /// 未知のフラグ・値のないフラグはエラーにする（typo が黙って無視されるのを防ぐ）
    static func parseOptions(_ args: [String]) throws -> Options {
        var options = Options()

        // --help / --version は他の引数が不正でも優先する（一般的な CLI の慣例に合わせ、
        // usage を見たいだけのユーザーが Unknown argument で弾かれないようにする）
        if args.contains("--help") || args.contains("-h") {
            options.showHelp = true
            return options
        }
        if args.contains("--version") {
            options.showVersion = true
            return options
        }

        var idx = args.startIndex
        while idx < args.endIndex {
            let arg = args[idx]
            switch arg {
            case "--config", "--dotenv", "--output":
                let valueIdx = args.index(after: idx)
                guard valueIdx < args.endIndex, !args[valueIdx].hasPrefix("--") else {
                    throw KuraError.invalidArguments("Missing value for \(arg)")
                }
                switch arg {
                case "--config": options.configPath = args[valueIdx]
                case "--dotenv": options.dotenvPath = args[valueIdx]
                default: options.outputPath = args[valueIdx]
                }
                idx = valueIdx
            default:
                throw KuraError.invalidArguments(
                    "Unknown argument '\(arg)'. Run 'kura-generator --help' for usage."
                )
            }
            idx = args.index(after: idx)
        }
        return options
    }
}
