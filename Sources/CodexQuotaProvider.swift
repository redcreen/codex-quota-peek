import Foundation

struct CodexAccountInfo {
    let displayName: String
    let email: String?
    let planDisplayName: String
}

struct CodexKnownAccount {
    let displayName: String
    let email: String?
    let accountID: String?
    let isCurrent: Bool
}

final class CodexQuotaProvider {
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func loadSnapshot() throws -> CodexQuotaSnapshot {
        if let live = try latestFromRealtimeLogs() {
            return live
        }
        if let archived = try latestFromArchivedSessions() {
            return archived
        }
        throw NSError(
            domain: "CodexQuotaPeek",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No Codex rate limit data found in ~/.codex."]
        )
    }

    func loadAccountInfo() -> CodexAccountInfo? {
        let authURL = homeDirectory.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: authURL),
              let auth = try? decoder.decode(CodexAuthFile.self, from: data) else {
            return nil
        }

        let payload = decodeJWTPayload(token: auth.tokens.idToken) ?? decodeJWTPayload(token: auth.tokens.accessToken)
        let displayName = payload?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = payload?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = payload?.auth?.chatgptPlanType?.trimmingCharacters(in: .whitespacesAndNewlines)

        let finalName = [displayName, email].compactMap { (value: String?) -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.first

        let finalPlan = plan.map { Self.humanizePlan($0) } ?? "Unknown"

        guard let finalName else { return nil }
        return CodexAccountInfo(displayName: finalName, email: email, planDisplayName: finalPlan)
    }

    func loadKnownAccounts() -> [CodexKnownAccount] {
        var results: [CodexKnownAccount] = []
        var seen = Set<String>()

        let current = loadAccountInfo()
        let currentAccountID = loadCurrentAccountID()
        if let current {
            let key = [current.email ?? "", currentAccountID ?? ""].joined(separator: "|")
            seen.insert(key)
            results.append(
                CodexKnownAccount(
                    displayName: current.displayName,
                    email: current.email,
                    accountID: currentAccountID,
                    isCurrent: true
                )
            )
        }

        let dbPath = homeDirectory.appendingPathComponent(".codex/logs_1.sqlite").path
        guard fileManager.fileExists(atPath: dbPath) else { return results }

        let sql = """
        select feedback_log_body
        from logs
        where feedback_log_body like '%user.email="%'
        order by id desc
        limit 500;
        """

        guard let output = try? runSQLite(databasePath: dbPath, sql: sql) else { return results }
        let emailRegex = try? NSRegularExpression(pattern: #"user\.email="([^"]+)""#)
        let accountRegex = try? NSRegularExpression(pattern: #"user\.account_id="([^"]+)""#)

        for line in output.split(separator: "\n") {
            let text = String(line)
            let email = firstMatch(in: text, regex: emailRegex)
            let accountID = firstMatch(in: text, regex: accountRegex)
            guard let email else { continue }

            let key = [email, accountID ?? ""].joined(separator: "|")
            if seen.contains(key) { continue }
            seen.insert(key)

            results.append(
                CodexKnownAccount(
                    displayName: email,
                    email: email,
                    accountID: accountID,
                    isCurrent: false
                )
            )
        }

        return results
    }

    private func latestFromRealtimeLogs() throws -> CodexQuotaSnapshot? {
        let dbPath = homeDirectory.appendingPathComponent(".codex/logs_1.sqlite").path
        guard fileManager.fileExists(atPath: dbPath) else { return nil }

        let sql = """
        select feedback_log_body
        from logs
        where target = 'codex_api::endpoint::responses_websocket'
          and feedback_log_body like '%websocket event: {"type":"codex.rate_limits"%'
        order by id desc
        limit 20;
        """

        let output = try runSQLite(databasePath: dbPath, sql: sql)
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        for candidate in output.split(separator: "\n") {
            if let snapshot = try decodeSnapshotIfPossible(fromLogBody: String(candidate)) {
                return snapshot
            }
        }

        return nil
    }

    private func latestFromArchivedSessions() throws -> CodexQuotaSnapshot? {
        let directory = homeDirectory.appendingPathComponent(".codex/archived_sessions")
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let sortedFiles = try files.sorted {
            let lhsDate = try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }

        for file in sortedFiles {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n").reversed() {
                if line.contains("\"type\":\"token_count\""),
                   let snapshot = try decodeSnapshotFromArchivedLine(String(line)) {
                    return snapshot
                }
            }
        }

        return nil
    }

    private func decodeSnapshotFromArchivedLine(_ line: String) throws -> CodexQuotaSnapshot? {
        guard let data = line.data(using: .utf8) else { return nil }
        let wrapper = try decoder.decode(ArchivedSessionEnvelope.self, from: data)
        guard wrapper.type == "event_msg", wrapper.payload.type == "token_count", let rateLimits = wrapper.payload.rateLimits else {
            return nil
        }

        return CodexQuotaSnapshot(planType: rateLimits.planType, rateLimits: rateLimits.toRateLimits())
    }

    private func decodeSnapshotIfPossible(fromLogBody logBody: String) throws -> CodexQuotaSnapshot? {
        guard let jsonString = extractJSONObject(in: logBody, prefix: #"websocket event: {"type":"codex.rate_limits""#)?
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .last
            .map({ String($0).trimmingCharacters(in: .whitespaces) }),
              let data = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let event = try decoder.decode(RateLimitEvent.self, from: data)
            return CodexQuotaSnapshot(planType: event.planType, rateLimits: event.rateLimits)
        } catch {
            return nil
        }
    }

    private func extractJSONObject(in text: String, prefix: String) -> String? {
        guard let start = text.range(of: prefix)?.lowerBound else { return nil }

        var depth = 0
        var inString = false
        var isEscaping = false
        var current = start

        while current < text.endIndex {
            let character = text[current]

            if inString {
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[start...current])
                    }
                }
            }

            current = text.index(after: current)
        }

        return nil
    }

    private func runSQLite(databasePath: String, sql: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [databasePath, sql]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "CodexQuotaPeek",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: error.isEmpty ? "sqlite3 exited with code \(process.terminationStatus)." : error]
            )
        }

        return output
    }

    private func decodeJWTPayload(token: String?) -> JWTClaims? {
        guard let token else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while payload.count % 4 != 0 {
            payload.append("=")
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? decoder.decode(JWTClaims.self, from: data)
    }

    private static func humanizePlan(_ plan: String) -> String {
        plan
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private func loadCurrentAccountID() -> String? {
        let authURL = homeDirectory.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: authURL),
              let auth = try? decoder.decode(CodexAuthFile.self, from: data) else {
            return nil
        }
        return auth.tokens.accountID
    }

    private func firstMatch(in text: String, regex: NSRegularExpression?) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}

private struct RateLimitEvent: Decodable {
    let planType: String?
    let rateLimits: RateLimits

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimits = "rate_limits"
    }
}

private struct ArchivedSessionEnvelope: Decodable {
    let type: String
    let payload: ArchivedPayload
}

private struct ArchivedPayload: Decodable {
    let type: String
    let rateLimits: ArchivedRateLimits?

    enum CodingKeys: String, CodingKey {
        case type
        case info
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        if container.contains(.info) {
            let info = try container.decode(ArchivedInfo.self, forKey: .info)
            rateLimits = info.rateLimits
        } else {
            rateLimits = nil
        }
    }
}

private struct ArchivedInfo: Decodable {
    let rateLimits: ArchivedRateLimits?

    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
    }
}

private struct ArchivedRateLimits: Decodable {
    let primary: LimitWindow?
    let secondary: LimitWindow?
    let planType: String?

    enum CodingKeys: String, CodingKey {
        case primary
        case secondary
        case planType = "plan_type"
    }

    func toRateLimits() -> RateLimits {
        RateLimits(allowed: nil, limitReached: nil, primary: primary, secondary: secondary)
    }
}

private struct CodexAuthFile: Decodable {
    let tokens: AuthTokens
}

private struct AuthTokens: Decodable {
    let idToken: String?
    let accessToken: String?
    let accountID: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case accountID = "account_id"
    }
}

private struct JWTClaims: Decodable {
    let name: String?
    let email: String?
    let auth: JWTAuthClaims?

    enum CodingKeys: String, CodingKey {
        case name
        case email
        case auth = "https://api.openai.com/auth"
    }
}

private struct JWTAuthClaims: Decodable {
    let chatgptPlanType: String?

    enum CodingKeys: String, CodingKey {
        case chatgptPlanType = "chatgpt_plan_type"
    }
}
