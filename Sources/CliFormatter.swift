import Foundation

enum CliFormatter {
    static func formatStatus(
        presentation: StatusPresentation,
        fetchSource: CodexQuotaFetchSource,
        accountInfo: CodexAccountInfo?
    ) -> String {
        var lines: [String] = []
        lines.append("Codex Quota Peek")
        if let accountInfo {
            lines.append("Account: \(accountInfo.email ?? accountInfo.displayName)")
            lines.append("Plan: \(accountInfo.planDisplayName)")
        }
        lines.append("H: \(presentation.line1)")
        lines.append("W: \(presentation.line2)")
        if let primary = presentation.primaryRow {
            lines.append("Session: \(QuotaDisplayPolicy.progressBar(forPercentText: primary.percentText))  \(primary.percentText)  resets \(primary.resetText)")
        }
        if let secondary = presentation.secondaryRow {
            lines.append("Weekly:  \(QuotaDisplayPolicy.progressBar(forPercentText: secondary.percentText))  \(secondary.percentText)  resets \(secondary.resetText)")
        }
        if let creditsText = presentation.creditsText {
            lines.append("Credits: \(creditsText)")
        }
        if let pace = presentation.paceMessage {
            lines.append("Pace: \(pace)")
        }
        lines.append("Updated: \(presentation.updatedAtText)")
        lines.append("Source: \(fetchSource.menuLabel)")
        return lines.joined(separator: "\n")
    }

    static func formatAccountList(_ accounts: [CodexKnownAccount]) -> String {
        guard !accounts.isEmpty else {
            return "No accounts found."
        }

        return accounts.enumerated().map { index, account in
            let status: String
            if account.isCurrent {
                status = "current"
            } else if account.canSwitchLocally {
                status = "switchable"
            } else {
                status = "re-login"
            }

            let identity = account.email ?? account.displayName
            let plan = account.planDisplayName ?? "Unknown"
            let snapshot = account.snapshotIdentifier ?? "-"
            let saved = account.snapshotUpdatedAt.map { StatusPresentation.relativeUpdatedAtLabel(for: $0) } ?? "-"
            return "\(index + 1). \(identity)  [\(plan)]  status=\(status)  snapshot=\(snapshot)  saved=\(saved)"
        }.joined(separator: "\n")
    }
}
