import Foundation

enum CliExit: Int32 {
    case success = 0
    case usage = 64
    case failure = 1
}

@main
struct CodexQuotaPeekCLI {
    static func main() {
        let cli = CLI()
        exit(cli.run())
    }
}

private struct CLI {
    private let provider = CodexQuotaProvider()

    func run() -> Int32 {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.isEmpty {
            return printStatus(usingAPI: false, forcingAPI: false, json: false)
        }

        switch args[0] {
        case "help", "--help", "-h":
            printHelp()
            return CliExit.success.rawValue
        case "status":
            return handleStatus(Array(args.dropFirst()))
        case "json":
            return printStatus(usingAPI: false, forcingAPI: false, json: true)
        case "accounts":
            return handleAccounts(Array(args.dropFirst()))
        default:
            fputs("Unknown command: \(args[0])\n\n", stderr)
            printHelp()
            return CliExit.usage.rawValue
        }
    }

    private func handleStatus(_ args: [String]) -> Int32 {
        let forcingAPI = args.contains("--refresh")
        let usingAPI = args.contains("--api") || forcingAPI
        let json = args.contains("--json")
        return printStatus(usingAPI: usingAPI, forcingAPI: forcingAPI, json: json)
    }

    private func printStatus(usingAPI: Bool, forcingAPI: Bool, json: Bool) -> Int32 {
        do {
            let result = try {
                if forcingAPI {
                    return try provider.loadSnapshotUsingAPI()
                }
                if usingAPI {
                    return try provider.loadSnapshotUsingAPIOrFallback()
                }
                return try provider.loadSnapshotForAutomaticRefresh()
            }()
            let accountInfo = provider.loadAccountInfo()
            let generatedAt = Date()
            let presentation = StatusPresentation(
                snapshot: result.snapshot,
                accountInfo: accountInfo,
                generatedAt: generatedAt,
                source: result.source
            )

            if json {
                try printJSON(result: result, presentation: presentation, accountInfo: accountInfo)
            } else {
                print(CliFormatter.formatStatus(
                    presentation: presentation,
                    fetchSource: result.source,
                    accountInfo: accountInfo
                ))
            }
            return CliExit.success.rawValue
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            return CliExit.failure.rawValue
        }
    }

    private func printJSON(
        result: CodexQuotaFetchResult,
        presentation: StatusPresentation,
        accountInfo: CodexAccountInfo?
    ) throws {
        var object: [String: Any] = [
            "source": result.source.menuLabel,
            "status": [
                "line1": presentation.line1,
                "line2": presentation.line2,
                "updated": presentation.updatedAtText
            ]
        ]

        if let accountInfo {
            object["account"] = [
                "display_name": accountInfo.displayName,
                "email": accountInfo.email as Any,
                "plan": accountInfo.planDisplayName
            ]
        }

        if let primary = presentation.primaryRow {
            object["session"] = [
                "label": primary.label,
                "percent": primary.percentText,
                "reset": primary.resetText
            ]
        }

        if let secondary = presentation.secondaryRow {
            object["weekly"] = [
                "label": secondary.label,
                "percent": secondary.percentText,
                "reset": secondary.resetText
            ]
        }

        if let credits = presentation.creditsText {
            object["credits"] = credits
        }

        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }

    private func handleAccounts(_ args: [String]) -> Int32 {
        guard let command = args.first else {
            printAccountsHelp()
            return CliExit.usage.rawValue
        }

        switch command {
        case "list":
            let accounts = provider.loadKnownAccounts()
            print(CliFormatter.formatAccountList(accounts))
            return CliExit.success.rawValue
        case "save":
            guard let account = provider.captureCurrentAuthSnapshot() else {
                fputs("Could not save current account snapshot.\n", stderr)
                return CliExit.failure.rawValue
            }
            print("Saved snapshot for \(account.email ?? account.displayName) [\(account.snapshotIdentifier)]")
            return CliExit.success.rawValue
        case "switch":
            guard args.count >= 2 else {
                fputs("Missing account identifier.\n", stderr)
                printAccountsHelp()
                return CliExit.usage.rawValue
            }
            return switchAccount(args[1])
        default:
            fputs("Unknown accounts command: \(command)\n", stderr)
            printAccountsHelp()
            return CliExit.usage.rawValue
        }
    }

    private func switchAccount(_ query: String) -> Int32 {
        let accounts = provider.loadKnownAccounts()
        guard let account = accounts.first(where: {
            $0.snapshotIdentifier == query || $0.email == query || $0.displayName == query
        }) else {
            fputs("No account matched '\(query)'.\n", stderr)
            return CliExit.failure.rawValue
        }

        guard let snapshotIdentifier = account.snapshotIdentifier, account.canSwitchLocally else {
            fputs("Account '\(account.email ?? account.displayName)' is history-only and still requires re-login.\n", stderr)
            return CliExit.failure.rawValue
        }

        do {
            try provider.switchToStoredAccount(identifier: snapshotIdentifier)
            print("Switched to \(account.email ?? account.displayName)")
            return CliExit.success.rawValue
        } catch {
            fputs("Switch failed: \(error.localizedDescription)\n", stderr)
            return CliExit.failure.rawValue
        }
    }

    private func printHelp() {
        print(
            """
            codexQuotaPeek

            Usage:
              codexQuotaPeek
              codexQuotaPeek status [--api|--refresh] [--json]
              codexQuotaPeek json
              codexQuotaPeek accounts list
              codexQuotaPeek accounts save
              codexQuotaPeek accounts switch <snapshot-id|email|display-name>
              codexQuotaPeek help
            """
        )
    }

    private func printAccountsHelp() {
        print(
            """
            codexQuotaPeek accounts

            Usage:
              codexQuotaPeek accounts list
              codexQuotaPeek accounts save
              codexQuotaPeek accounts switch <snapshot-id|email|display-name>
            """
        )
    }
}
