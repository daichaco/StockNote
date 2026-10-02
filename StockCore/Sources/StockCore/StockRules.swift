import Foundation

public enum ExpiryStatus: Equatable, Sendable {
    case none
    case ok(daysLeft: Int)
    case soon(daysLeft: Int)
    case expired(daysOver: Int)
}

public enum AttentionReason: Equatable, Sendable {
    case low
    case expiringSoon(daysLeft: Int)
    case expired(daysOver: Int)
}

public enum StockRules {
    /// 購入日から何日たったか。時刻は無視し、未来の日付は 0 にする。
    public static func daysSincePurchase(_ purchasedAt: Date, now: Date, calendar: Calendar = .current) -> Int {
        max(0, dayDifference(from: purchasedAt, to: now, calendar: calendar))
    }

    /// 期限の当日は「あと0日」で、まだ切れていない。警告日数ちょうどから警告に入る。
    public static func expiryStatus(expiry: Date?, warnDays: Int, now: Date, calendar: Calendar = .current) -> ExpiryStatus {
        guard let expiry else { return .none }
        let left = dayDifference(from: now, to: expiry, calendar: calendar)
        if left < 0 { return .expired(daysOver: -left) }
        return left <= warnDays ? .soon(daysLeft: left) : .ok(daysLeft: left)
    }

    /// 期限の通知を出す日時(警告日の朝9時)。期限がなければ nil。過去かどうかは呼び出し側で判断する。
    public static func alertDate(expiry: Date?, warnDays: Int, calendar: Calendar = .current) -> Date? {
        guard let expiry,
              let day = calendar.date(byAdding: .day, value: -warnDays, to: calendar.startOfDay(for: expiry))
        else { return nil }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
    }

    static func dayDifference(from: Date, to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}

extension StockEntry {
    public func expiryStatus(now: Date, calendar: Calendar = .current) -> ExpiryStatus {
        StockRules.expiryStatus(expiry: expiry, warnDays: warnDays, now: now, calendar: calendar)
    }

    /// 「要確認」に入る理由。空なら通常の品。
    public func attention(now: Date, calendar: Calendar = .current) -> [AttentionReason] {
        var reasons: [AttentionReason] = []
        if isLow { reasons.append(.low) }
        switch expiryStatus(now: now, calendar: calendar) {
        case .soon(let d): reasons.append(.expiringSoon(daysLeft: d))
        case .expired(let d): reasons.append(.expired(daysOver: d))
        case .none, .ok: break
        }
        return reasons
    }
}
