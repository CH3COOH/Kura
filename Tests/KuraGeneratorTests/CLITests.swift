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
