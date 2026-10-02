import Foundation

public enum Presets {
    public static func categories(for kind: ItemKind) -> [String] {
        switch kind {
        case .food: ["野菜・果物", "肉・魚", "卵・乳製品", "主食(米・パン・麺)", "調味料", "飲料", "冷凍・レトルト", "お菓子", "その他"]
        case .daily: ["洗剤・洗濯", "キッチン用品", "トイレ・紙類", "入浴・スキンケア", "衛生・医薬", "掃除用品", "その他"]
        case .disaster: ["水・飲料", "非常食", "衛生・トイレ", "明かり・電源", "医薬・救急", "防寒・雨具", "貴重品・その他"]
        }
    }

    public struct KitItem: Equatable, Sendable {
        public let name: String
        public let category: String
        /// 期限がある品。追加後に期限を入れるよう促す。
        public let hasExpiry: Bool
    }

    /// 「防災バッグの定番」。一般的な備えの目安で、公的な推奨と同一ではない。
    public static let disasterKit: [KitItem] = [
        .init(name: "飲料水", category: "水・飲料", hasExpiry: true),
        .init(name: "非常食", category: "非常食", hasExpiry: true),
        .init(name: "携帯トイレ", category: "衛生・トイレ", hasExpiry: false),
        .init(name: "ウェットティッシュ", category: "衛生・トイレ", hasExpiry: false),
        .init(name: "マスク", category: "衛生・トイレ", hasExpiry: false),
        .init(name: "懐中電灯", category: "明かり・電源", hasExpiry: false),
        .init(name: "予備の電池", category: "明かり・電源", hasExpiry: true),
        .init(name: "モバイルバッテリー", category: "明かり・電源", hasExpiry: false),
        .init(name: "携帯ラジオ", category: "明かり・電源", hasExpiry: false),
        .init(name: "常備薬", category: "医薬・救急", hasExpiry: true),
        .init(name: "救急セット", category: "医薬・救急", hasExpiry: true),
        .init(name: "簡易カイロ", category: "防寒・雨具", hasExpiry: true),
        .init(name: "レインコート", category: "防寒・雨具", hasExpiry: false),
        .init(name: "軍手", category: "貴重品・その他", hasExpiry: false),
        .init(name: "ホイッスル", category: "貴重品・その他", hasExpiry: false),
        .init(name: "小銭", category: "貴重品・その他", hasExpiry: false),
    ]
}
