import Foundation

// エントリポイント（ロジックは KuraCLI に切り出してテスト可能にしている）
do {
    try KuraCLI(arguments: Array(CommandLine.arguments.dropFirst())).run()
} catch let error as KuraError {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
} catch {
    fputs("❌  Unexpected error: \(error)\n", stderr)
    exit(1)
}
