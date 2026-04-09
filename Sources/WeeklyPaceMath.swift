import Foundation

enum WeeklyPaceMath {
    static func activeElapsedFraction(
        resetAt: TimeInterval,
        resetAfterSeconds: Int,
        mode: WeeklyPacingMode
    ) -> Double {
        let windowSeconds = 7.0 * 24.0 * 60.0 * 60.0
        let resetDate = Date(timeIntervalSince1970: resetAt)
        let currentDate = resetDate.addingTimeInterval(-Double(resetAfterSeconds))
        let windowStart = resetDate.addingTimeInterval(-windowSeconds)
        let dailyActiveSeconds = mode.dailyActiveHours * 60.0 * 60.0
        let daySeconds = 24.0 * 60.0 * 60.0
        let totalActiveSeconds = Double(mode.weeklyHours) * 60.0 * 60.0
        guard totalActiveSeconds > 0 else { return 0 }

        var activeElapsedSeconds = 0.0
        for day in 0..<7 {
            let dayStart = windowStart.addingTimeInterval(Double(day) * daySeconds)
            if day >= mode.activeDaysPerWeek {
                continue
            }
            let activeStart = dayStart
            let activeEnd = dayStart.addingTimeInterval(dailyActiveSeconds)
            let overlapStart = max(activeStart.timeIntervalSince1970, windowStart.timeIntervalSince1970)
            let overlapEnd = min(activeEnd.timeIntervalSince1970, currentDate.timeIntervalSince1970)
            if overlapEnd > overlapStart {
                activeElapsedSeconds += overlapEnd - overlapStart
            }
        }

        return min(max(activeElapsedSeconds / totalActiveSeconds, 0), 1)
    }
}
