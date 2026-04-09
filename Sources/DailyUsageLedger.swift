import Foundation

struct DailyUsageLedgerDay {
    let date: Date
    let usedPercent: Double
    let cumulativeUsedPercent: Double
    let expectedUsedPercent: Double
    let expectedDailyUsedPercent: Double
    let isFuture: Bool

    var isAheadOfDailyPace: Bool {
        !isFuture && usedPercent > expectedDailyUsedPercent
    }
}

enum DailyUsageLedger {
    static func build(
        rows: [CodexQuotaFetchResult],
        calendar: Calendar = .current,
        latestObservedDate overrideLatestObservedDate: Date? = nil
    ) -> [DailyUsageLedgerDay] {
        guard let latestRow = rows.last,
              let window = latestRow.snapshot.rateLimits.secondary,
              let resetAt = window.resetAt,
              let windowMinutes = window.windowMinutes else {
            return []
        }

        let resetDate = Date(timeIntervalSince1970: resetAt)
        let windowStart = resetDate.addingTimeInterval(-Double(windowMinutes * 60))
        let startOfFirstDay = calendar.startOfDay(for: windowStart)
        let latestObservedDate = overrideLatestObservedDate ?? rows.last?.sourceDate ?? Date()

        let maximaByDay = Dictionary(
            grouping: rows.compactMap { row -> (Date, Double)? in
                guard let weekly = row.snapshot.rateLimits.secondary,
                      let date = row.sourceDate else { return nil }
                return (calendar.startOfDay(for: date), weekly.usedPercent)
            },
            by: { $0.0 }
        ).mapValues { entries in
            entries.map(\.1).max() ?? 0
        }

        let totalSeconds = Double(windowMinutes * 60)
        var previousMax: Double = 0
        var previousExpected: Double = 0

        return (0..<7).compactMap { offset in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: startOfFirstDay),
                  let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return nil
            }

            let dayMax = max(previousMax, maximaByDay[dayStart] ?? previousMax)
            let dailyPercent = max(0, dayMax - previousMax)
            previousMax = dayMax

            let comparisonDate = min(nextDayStart, resetDate, latestObservedDate)
            let elapsedSeconds = max(0, comparisonDate.timeIntervalSince(windowStart))
            let expectedUsedPercent = min(100, max(0, elapsedSeconds / totalSeconds * 100.0))
            let expectedDailyUsedPercent = max(0, expectedUsedPercent - previousExpected)
            previousExpected = expectedUsedPercent
            let isFuture = dayStart > calendar.startOfDay(for: latestObservedDate)

            return DailyUsageLedgerDay(
                date: dayStart,
                usedPercent: dailyPercent,
                cumulativeUsedPercent: dayMax,
                expectedUsedPercent: expectedUsedPercent,
                expectedDailyUsedPercent: expectedDailyUsedPercent,
                isFuture: isFuture
            )
        }
    }
}
