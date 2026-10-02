import Foundation
import StockCore
import SwiftData

@Model
final class Item {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var category: String
    var purchasedAt: Date
    /// 0.0(空)〜1.0(満タン)
    var remaining: Double
    var tracksRemaining: Bool
    var lowThreshold: Double
    var expiry: Date?
    var warnDays: Int
    var quantity: Int
    var lastCheckedAt: Date?
    var note: String
    var createdAt: Date

    init(name: String, kind: ItemKind, category: String, purchasedAt: Date = .now, remaining: Double = 1,
         tracksRemaining: Bool? = nil, lowThreshold: Double = 0.25, expiry: Date? = nil, warnDays: Int? = nil,
         quantity: Int = 1, note: String = "") {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.category = category
        self.purchasedAt = purchasedAt
        self.remaining = remaining
        self.tracksRemaining = tracksRemaining ?? kind.tracksRemainingByDefault
        self.lowThreshold = lowThreshold
        self.expiry = expiry
        self.warnDays = warnDays ?? kind.defaultWarnDays
        self.quantity = quantity
        self.lastCheckedAt = nil
        self.note = note
        self.createdAt = .now
    }

    var kind: ItemKind {
        get { ItemKind(rawValue: kindRaw) ?? .daily }
        set { kindRaw = newValue.rawValue }
    }

    var entry: StockEntry {
        StockEntry(id: id, name: name, kind: kind, remaining: remaining, tracksRemaining: tracksRemaining,
                   lowThreshold: lowThreshold, purchasedAt: purchasedAt, expiry: expiry, warnDays: warnDays)
    }
}

/// 残量を変えるたびの記録。今は表示しないが、後で「なくなるペース」の予測に使う。
@Model
final class RemainingLog {
    var itemID: UUID
    var date: Date
    var value: Double

    init(itemID: UUID, value: Double, date: Date = .now) {
        self.itemID = itemID
        self.value = value
        self.date = date
    }
}

/// ユーザーが追加したカテゴリ(用意済みのカテゴリは StockCore の `Presets`)
@Model
final class CustomCategory {
    var name: String
    var kindRaw: String

    init(name: String, kind: ItemKind) {
        self.name = name
        self.kindRaw = kind.rawValue
    }

    var kind: ItemKind { ItemKind(rawValue: kindRaw) ?? .daily }
}

enum ItemActions {
    static func setRemaining(_ item: Item, to value: Double, in context: ModelContext) {
        let v = RemainingStep.snap(value)
        item.remaining = v
        context.insert(RemainingLog(itemID: item.id, value: v))
    }

    /// 「買った」: 満タンに戻し、購入日を今日にする。古い期限が残らないよう期限は空にする。
    static func restock(_ item: Item, in context: ModelContext) {
        item.purchasedAt = .now
        item.expiry = nil
        setRemaining(item, to: 1, in: context)
    }

    /// 「点検した」(防災バッグ用)
    static func markChecked(_ item: Item) {
        item.lastCheckedAt = .now
    }

    static func delete(_ item: Item, in context: ModelContext) {
        let id = item.id
        let logs = (try? context.fetch(FetchDescriptor<RemainingLog>(predicate: #Predicate { $0.itemID == id }))) ?? []
        logs.forEach(context.delete)
        context.delete(item)
    }
}

enum Categories {
    static func all(for kind: ItemKind, custom: [CustomCategory]) -> [String] {
        Presets.categories(for: kind) + custom.filter { $0.kind == kind }.map(\.name)
    }
}
