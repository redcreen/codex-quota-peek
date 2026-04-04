import Foundation

struct CodexStoredAccount {
    let snapshotIdentifier: String
    let displayName: String
    let email: String?
    let accountID: String?
    let planDisplayName: String
    let updatedAt: Date?
}

final class CodexAuthSnapshotStore {
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func saveCurrentAuthSnapshot() -> CodexStoredAccount? {
        let authURL = liveAuthURL
        guard let data = try? Data(contentsOf: authURL),
              let account = decodeStoredAccount(from: data) else {
            return nil
        }

        let directory = snapshotsDirectory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let targetURL = directory.appendingPathComponent("\(account.snapshotIdentifier).json")
        do {
            try data.write(to: targetURL, options: [.atomic])
        } catch {
            return nil
        }

        return storedAccount(at: targetURL)
    }

    func loadStoredAccounts() -> [CodexStoredAccount] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap(storedAccount(at:)).sorted {
            let lhsDate = $0.updatedAt ?? .distantPast
            let rhsDate = $1.updatedAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    func restoreSnapshot(identifier: String) throws {
        let sourceURL = snapshotsDirectory.appendingPathComponent("\(identifier).json")
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: liveAuthURL, options: [.atomic])
    }

    private func storedAccount(at url: URL) -> CodexStoredAccount? {
        guard let data = try? Data(contentsOf: url),
              var account = decodeStoredAccount(from: data) else {
            return nil
        }

        let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        account = CodexStoredAccount(
            snapshotIdentifier: account.snapshotIdentifier,
            displayName: account.displayName,
            email: account.email,
            accountID: account.accountID,
            planDisplayName: account.planDisplayName,
            updatedAt: modifiedAt ?? nil
        )
        return account
    }

    private func decodeStoredAccount(from data: Data) -> CodexStoredAccount? {
        guard let auth = try? decoder.decode(CodexAuthFile.self, from: data) else {
            return nil
        }

        let claims = decodeJWTPayload(token: auth.tokens.idToken) ?? decodeJWTPayload(token: auth.tokens.accessToken)
        let email = claims?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = claims?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountID = auth.tokens.accountID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = claims?.auth?.chatgptPlanType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = [displayName, email].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.first

        guard let finalName else { return nil }
        let fallbackIdentifier = email?
            .replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: ".", with: "_")
        let snapshotIdentifier = accountID ?? fallbackIdentifier ?? UUID().uuidString

        return CodexStoredAccount(
            snapshotIdentifier: snapshotIdentifier,
            displayName: finalName,
            email: email,
            accountID: accountID,
            planDisplayName: plan.map(CodexQuotaProvider.humanizePlan) ?? "Unknown",
            updatedAt: nil
        )
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

    private var liveAuthURL: URL {
        homeDirectory.appendingPathComponent(".codex/auth.json")
    }

    private var snapshotsDirectory: URL {
        homeDirectory.appendingPathComponent(".codex/quota_peek_auth_snapshots")
    }
}
