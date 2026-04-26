import Foundation

struct RefreshDiagnosticsLogger {
    private let fileURL: URL
    private let formatter: ISO8601DateFormatter
    private let queue = DispatchQueue(label: "codex.quota.peek.refresh-diagnostics")

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        fileURL = homeDirectory
            .appendingPathComponent(".codex")
            .appendingPathComponent("codex-quota-peek.log")
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func log(
        event: String,
        mode: QuotaRefreshMode? = nil,
        details: [String: String] = [:],
        now: Date = Date()
    ) {
        let line = Self.makeLine(
            timestamp: formatter.string(from: now),
            event: event,
            mode: mode,
            details: details
        )

        queue.async {
            let directory = self.fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let data = Data((line + "\n").utf8)
            if FileManager.default.fileExists(atPath: self.fileURL.path),
               let handle = try? FileHandle(forWritingTo: self.fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: self.fileURL, options: .atomic)
            }
        }
    }

    static func makeLine(
        timestamp: String,
        event: String,
        mode: QuotaRefreshMode?,
        details: [String: String]
    ) -> String {
        var parts = ["[\(timestamp)]", event]
        if let mode {
            parts.append("mode=\(mode.logLabel)")
        }
        details.keys.sorted().forEach { key in
            let value = details[key] ?? ""
            parts.append("\(key)=\(value.replacingOccurrences(of: "\n", with: " "))")
        }
        return parts.joined(separator: " ")
    }
}

private extension QuotaRefreshMode {
    var logLabel: String {
        switch self {
        case .automatic:
            return "automatic"
        case .apiManual:
            return "apiManual"
        case .startupAPI:
            return "startupAPI"
        }
    }
}
