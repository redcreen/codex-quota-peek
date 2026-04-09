import Foundation

struct AccountMenuEntry {
    let title: String
    let isEnabled: Bool
}

enum AccountMenuBuilder {
    static func buildEntries(
        accounts: [CodexKnownAccount],
        language: AppLanguage,
        relativeUpdatedAt: (Date) -> String
    ) -> [AccountMenuEntry] {
        accounts.map { account in
            let suffix: String
            if let date = account.snapshotUpdatedAt {
                suffix = language.savedSuffix(relativeUpdatedAt(date))
            } else {
                suffix = ""
            }
            let planSuffix = account.planDisplayName.map { " (\($0))" } ?? ""

            let title: String
            if account.isCurrent {
                title = language.currentAccountTitle(account.displayName) + planSuffix + suffix
            } else if account.canSwitchLocally {
                title = language.switchToAccountTitle(account.displayName) + planSuffix + suffix
            } else {
                title = language.reloginAccountTitle(account.displayName)
            }

            return AccountMenuEntry(
                title: title,
                isEnabled: !account.isCurrent
            )
        }
    }
}
