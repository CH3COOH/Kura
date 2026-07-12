import Testing
import Foundation
@testable import KuraGenerator

struct CLITests {

    @Test func parsesAllValueOptions() throws {
        let options = try KuraCLI.parseOptions([
            "--config", "conf.yml",
            "--dotenv", "secrets.env",
            "--output", "Generated",
        ])
        #expect(options.configPath == "conf.yml")
        #expect(options.dotenvPath == "secrets.env")
        #expect(options.outputPath == "Generated")
        #expect(!options.showHelp)
        #expect(!options.showVersion)
    }

    @Test func parsesEmptyArgumentsAsDefaults() throws {
        let options = try KuraCLI.parseOptions([])
        #expect(options == KuraCLI.Options())
    }

    @Test func parsesHelpAndVersionFlags() throws {
        #expect(try KuraCLI.parseOptions(["--help"]).showHelp)
        #expect(try KuraCLI.parseOptions(["-h"]).showHelp)
        #expect(try KuraCLI.parseOptions(["--version"]).showVersion)
    }

    @Test func helpTakesPrecedenceOverInvalidArguments() throws {
        // usage を見たいだけのユーザーが Unknown argument で弾かれないようにする
        #expect(try KuraCLI.parseOptions(["--help", "--bogus"]).showHelp)
        #expect(try KuraCLI.parseOptions(["--bogus", "-h"]).showHelp)
        #expect(try KuraCLI.parseOptions(["--config", "--help"]).showHelp)
    }

    @Test func versionTakesPrecedenceOverInvalidArguments() throws {
        #expect(try KuraCLI.parseOptions(["--bogus", "--version"]).showVersion)
    }

    @Test func helpTakesPrecedenceOverVersion() throws {
        let options = try KuraCLI.parseOptions(["--version", "--help"])
        #expect(options.showHelp)
        #expect(!options.showVersion)
    }

    @Test func throwsOnUnknownArgument() throws {
        do {
            _ = try KuraCLI.parseOptions(["--confg", "conf.yml"])
            Issue.record("Expected KuraError.invalidArguments to be thrown")
        } catch KuraError.invalidArguments {
            // expected
        }
    }

    @Test func throwsWhenValueIsMissing() throws {
        do {
            _ = try KuraCLI.parseOptions(["--config"])
            Issue.record("Expected KuraError.invalidArguments to be thrown")
        } catch KuraError.invalidArguments {
            // expected
        }
    }

    @Test func throwsWhenValueLooksLikeAnotherFlag() throws {
        do {
            _ = try KuraCLI.parseOptions(["--config", "--output", "Generated"])
            Issue.record("Expected KuraError.invalidArguments to be thrown")
        } catch KuraError.invalidArguments {
            // expected
        }
    }

    @Test func lastValueWinsWhenFlagIsRepeated() throws {
        let options = try KuraCLI.parseOptions(["--config", "a.yml", "--config", "b.yml"])
        #expect(options.configPath == "b.yml")
    }
}
