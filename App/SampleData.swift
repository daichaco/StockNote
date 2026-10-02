#if DEBUG
import Foundation
import SwiftData

/// 起動引数 `-resetData` で全データを消し、`-seedSampleData` で見本の品目を入れる
/// (動作確認・UI テスト・スクリーンショット用。Release には入らない)。画面が出る前に呼ぶ。
enum SampleData {
    static func prepare(_ context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetData") {
            try? context.delete(model: Item.self)
            try? context.delete(model: RemainingLog.self)
            try? context.delete(model: CustomCategory.self)
        }
        guard args.contains("-seedSampleData"),
              ((try? context.fetchCount(FetchDescriptor<Item>())) ?? 0) == 0 else { return }
        let cal = Calendar.current
        func ago(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: .now)! }
        func ahead(_ d: Int) -> Date { cal.startOfDay(for: cal.date(byAdding: .day, value: d, to: .now)!) }

        let items: [Item] = [
            Item(name: "食器用洗剤", kind: .daily, category: "洗剤・洗濯", purchasedAt: ago(41), remaining: 0.25),
            Item(name: "シャンプー", kind: .daily, category: "入浴・スキンケア", purchasedAt: ago(20), remaining: 0.5),
            Item(name: "トイレットペーパー", kind: .daily, category: "トイレ・紙類", purchasedAt: ago(9), remaining: 0.75),
            Item(name: "牛乳", kind: .food, category: "卵・乳製品", purchasedAt: ago(4), remaining: 0.25, expiry: ahead(2), warnDays: 3),
            Item(name: "しょうゆ", kind: .food, category: "調味料", purchasedAt: ago(30), remaining: 0.5, expiry: ahead(120)),
            Item(name: "ヨーグルト", kind: .food, category: "卵・乳製品", purchasedAt: ago(12), remaining: 1, expiry: ahead(-2), warnDays: 3),
            Item(name: "飲料水", kind: .disaster, category: "水・飲料", purchasedAt: ago(200), expiry: ahead(25), quantity: 6),
            Item(name: "非常食", kind: .disaster, category: "非常食", purchasedAt: ago(200), expiry: ahead(400), quantity: 3),
            Item(name: "携帯トイレ", kind: .disaster, category: "衛生・トイレ", purchasedAt: ago(200), quantity: 10),
            Item(name: "予備の電池", kind: .disaster, category: "明かり・電源", purchasedAt: ago(200), expiry: ahead(300)),
        ]
        items.forEach(context.insert)
        items.last?.lastCheckedAt = ago(30)
    }
}
#endif
