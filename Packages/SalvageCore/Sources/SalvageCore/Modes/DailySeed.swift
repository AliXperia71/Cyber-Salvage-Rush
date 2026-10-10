import Foundation

/// Everyone gets the same daily run, rolling over at 00:00 UTC.
public enum DailySeed {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// `yyyyMMdd` in UTC. Also usable as a stable key for "today's best".
    public static func dayKey(for date: Date) -> String {
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year!, parts.month!, parts.day!)
    }

    public static func seed(for date: Date, configVersion: Int = GameConfig.current.version) -> UInt64 {
        StableHash.fnv1a("CSR-daily-v\(configVersion)-\(dayKey(for: date))")
    }

    /// When the next daily unlocks.
    public static func nextReset(after date: Date) -> Date {
        let start = utc.startOfDay(for: date)
        return utc.date(byAdding: .day, value: 1, to: start)!
    }
}
