import Foundation

enum KuraError: LocalizedError {
    case invalidConfig(String)
    case missingSecret(String)
    case ioError(String)

    var errorDescription: String? {
        switch self {
        case let .invalidConfig(msg):
            return "❌  Config error: \(msg)"
        case let .missingSecret(key):
            return "❌  Secret '\(key)' not found in .kura.yml or environment variables"
        case let .ioError(msg):
            return "❌  IO error: \(msg)"
        }
    }
}
