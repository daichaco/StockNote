import Foundation

/// 品目の種別。防災バッグは消費しない前提なので、残量ではなく期限と点検を主に扱う。
public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case food, daily, disaster

    public var title: String {
        switch self {
        case .food: "食品"
        case .daily: "日用品"
        case .disaster: "防災バッグ"
        }
    }

    /// 追加時の「残量を記録する」の初期値
    public var tracksRemainingByDefault: Bool { self != .disaster }

    /// 期限を「何日前から」警告するかの初期値
    public var defaultWarnDays: Int { self == .disaster ? 90 : 30 }
}

/// 判定に必要な項目だけを取り出した値。SwiftData のモデルに依存せずテストできるようにしてある。
public struct StockEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var kind: ItemKind
    /// 0.0(空)〜1.0(満タン)
    public var remaining: Double
    public var tracksRemaining: Bool
    public var lowThreshold: Double
    public var purchasedAt: Date
    public var expiry: Date?
    public var warnDays: Int

    public init(id: UUID, name: String, kind: ItemKind, remaining: Double, tracksRemaining: Bool,
                lowThreshold: Double, purchasedAt: Date, expiry: Date?, warnDays: Int) {
        self.id = id
        self.name = name
        self.kind = kind
        self.remaining = remaining
        self.tracksRemaining = tracksRemaining
        self.lowThreshold = lowThreshold
        self.purchasedAt = purchasedAt
        self.expiry = expiry
        self.warnDays = warnDays
    }

    /// しきい値ちょうども「少ない」に含める。残量を記録しない品は対象外。
    public var isLow: Bool { tracksRemaining && remaining <= lowThreshold }
}

/// スライダーは 25% 刻み(気づいたときにさっと動かせるように、細かくしすぎない)。
public enum RemainingStep {
    public static let steps = 4

    public static func snap(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return (clamped * Double(steps)).rounded() / Double(steps)
    }
}
