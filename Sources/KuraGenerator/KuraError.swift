import Foundation

enum KuraError: LocalizedError {
    case invalidConfig(String)
    case invalidArguments(String)
    case missingSecret(String)

    var errorDescription: String? {
        switch self {
        case let .invalidConfig(msg):
            return "❌  Config error: \(msg)"
        case let .invalidArguments(msg):
            return "❌  Argument error: \(msg)"
        case let .missingSecret(key):
            return "❌  Secret '\(key)' not found in environment variables or .env file"
        }
    }
}
