import Foundation

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

    private func latestFromRealtimeLogs() throws -> CodexQuotaSnapshot? {
        let dbPath = homeDirectory.appendingPathComponent(".codex/logs_1.sqlite").path
        guard fileManager.fileExists(atPath: dbPath) else { return nil }

        let sql = """
        select feedback_log_body
        from logs
        where feedback_log_body like '%websocket event: {"type":"codex.rate_limits"%'
        order by id desc
        limit 1;
        """

        let output = try runSQLite(databasePath: dbPath, sql: sql)
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return try decodeSnapshot(fromLogBody: output)
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

    private func decodeSnapshot(fromLogBody logBody: String) throws -> CodexQuotaSnapshot {
        guard let jsonString = extractJSONObject(in: logBody, prefix: #"{"type":"codex.rate_limits""#),
              let data = jsonString.data(using: .utf8) else {
            throw NSError(
                domain: "CodexQuotaPeek",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not parse Codex rate limit event."]
            )
        }

        let event = try decoder.decode(RateLimitEvent.self, from: data)
        return CodexQuotaSnapshot(planType: event.planType, rateLimits: event.rateLimits)
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
