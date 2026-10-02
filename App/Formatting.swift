import Foundation
import StockCore
import SwiftUI

enum Fmt {
    /// 今年の日付は年を省く
    static func date(_ d: Date) -> String {
        let sameYear = Calendar.current.isDate(d, equalTo: .now, toGranularity: .year)
        return sameYear ? d.formatted(.dateTime.month().day()) : d.formatted(.dateTime.year().month().day())
    }

    static func percent(_ v: Double) -> String {
        "\(Int((v * 100).rounded()))%"
    }

    static func threshold(_ v: Double) -> String {
        v == 0 ? "空になったら" : "\(percent(v))以下"
    }

    static func purchase(_ purchasedAt: Date, now: Date) -> String {
        let days = StockRules.daysSincePurchase(purchasedAt, now: now)
        return days == 0 ? "今日購入" : "購入 \(date(purchasedAt))(\(days)日前)"
    }

    static func expiry(_ expiry: Date, status: ExpiryStatus) -> String {
        switch status {
        case .none: ""
        case .ok(let d), .soon(let d): d == 0 ? "期限 \(date(expiry))(今日)" : "期限 \(date(expiry))(あと\(d)日)"
        case .expired(let d): "期限 \(date(expiry))(\(d)日過ぎ)"
        }
    }

    static func badge(_ reason: AttentionReason) -> (text: String, color: Color) {
        switch reason {
        case .low: ("残りわずか", .orange)
        case .expiringSoon(let d): (d == 0 ? "期限は今日" : "期限まで\(d)日", .orange)
        case .expired: ("期限切れ", .red)
        }
    }
}
