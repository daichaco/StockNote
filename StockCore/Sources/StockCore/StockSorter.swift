import Foundation

public struct StockSections: Equatable, Sendable {
    /// 先頭に強調して出す品(残量が少ない・期限が近い/過ぎた)
    public var attention: [StockEntry]
    public var others: [StockEntry]
}

public enum StockSorter {
    /// 要確認: 期限切れ(過ぎた日数が多い順)→ 残量が少ない(少ない順)→ 期限が近い(近い順)。
    /// その他: 残量を記録する品(少ない順)→ 記録しない品(期限が近い順、期限なしは最後)。
    public static func sections(_ entries: [StockEntry], now: Date, calendar: Calendar = .current) -> StockSections {
        var attention: [(StockEntry, AttentionKey)] = []
        var others: [StockEntry] = []
        for e in entries {
            let reasons = e.attention(now: now, calendar: calendar)
            if reasons.isEmpty {
                others.append(e)
            } else {
                attention.append((e, AttentionKey(reasons: reasons, remaining: e.remaining)))
            }
        }
        attention.sort { a, b in
            a.1 == b.1 ? a.0.name < b.0.name : a.1 < b.1
        }
        others.sort { a, b in
            let ka = OtherKey(a, now: now, calendar: calendar), kb = OtherKey(b, now: now, calendar: calendar)
            return ka == kb ? a.name < b.name : ka < kb
        }
        return StockSections(attention: attention.map(\.0), others: others)
    }
}

private struct AttentionKey: Comparable {
    var rank: Int
    var value: Double

    init(reasons: [AttentionReason], remaining: Double) {
        if let over = reasons.compactMap({ if case .expired(let d) = $0 { d } else { nil } }).first {
            rank = 0; value = -Double(over)
        } else if reasons.contains(.low) {
            rank = 1; value = remaining
        } else {
            let left = reasons.compactMap { if case .expiringSoon(let d) = $0 { d } else { nil } }.first ?? 0
            rank = 2; value = Double(left)
        }
    }

    static func < (a: AttentionKey, b: AttentionKey) -> Bool {
        a.rank == b.rank ? a.value < b.value : a.rank < b.rank
    }
}

private struct OtherKey: Comparable {
    var group: Int
    var value: Double

    init(_ e: StockEntry, now: Date, calendar: Calendar) {
        if e.tracksRemaining {
            group = 0; value = e.remaining
        } else {
            group = 1
            if let expiry = e.expiry {
                value = Double(StockRules.dayDifference(from: now, to: expiry, calendar: calendar))
            } else {
                value = .greatestFiniteMagnitude
            }
        }
    }

    static func < (a: OtherKey, b: OtherKey) -> Bool {
        a.group == b.group ? a.value < b.value : a.group < b.group
    }
}
