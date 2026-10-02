import Foundation
import Testing
@testable import StockCore

// 日付は「日本の暦・正午」で固定して、時刻のずれに左右されないようにする
private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return c
}

private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}

private let today = day(2026, 9, 28)

private func entry(
    _ name: String = "品",
    kind: ItemKind = .daily,
    remaining: Double = 1,
    tracks: Bool = true,
    threshold: Double = 0.2,
    purchased: Date = day(2026, 9, 1),
    expiry: Date? = nil,
    warnDays: Int = 30
) -> StockEntry {
    StockEntry(id: UUID(), name: name, kind: kind, remaining: remaining, tracksRemaining: tracks,
               lowThreshold: threshold, purchasedAt: purchased, expiry: expiry, warnDays: warnDays)
}

// MARK: 残量

@Test func lowIsInclusiveAtThreshold() {
    #expect(entry(remaining: 0.2, threshold: 0.2).isLow)
    #expect(entry(remaining: 0.19, threshold: 0.2).isLow)
    #expect(!entry(remaining: 0.21, threshold: 0.2).isLow)
}

@Test func lowIgnoredWhenNotTrackingRemaining() {
    #expect(!entry(remaining: 0, tracks: false).isLow)
}

@Test func snapsToQuarters() {
    #expect(RemainingStep.snap(0.30) == 0.25)
    #expect(RemainingStep.snap(0.38) == 0.5)
    #expect(RemainingStep.snap(-1) == 0)
    #expect(RemainingStep.snap(2) == 1)
}

// MARK: 購入日

@Test func daysSincePurchase() {
    #expect(StockRules.daysSincePurchase(day(2026, 9, 1), now: today, calendar: cal) == 27)
    #expect(StockRules.daysSincePurchase(today, now: today, calendar: cal) == 0)
}

@Test func daysSincePurchaseIgnoresTimeOfDay() {
    // 前日の23時に買った → 翌朝は1日前
    #expect(StockRules.daysSincePurchase(day(2026, 9, 27, hour: 23), now: day(2026, 9, 28, hour: 6), calendar: cal) == 1)
}

@Test func futurePurchaseDateIsClampedToZero() {
    #expect(StockRules.daysSincePurchase(day(2026, 10, 5), now: today, calendar: cal) == 0)
}

// MARK: 期限

@Test func noExpiry() {
    #expect(StockRules.expiryStatus(expiry: nil, warnDays: 30, now: today, calendar: cal) == .none)
}

@Test func expiryFarAway() {
    let e = day(2026, 12, 31)
    #expect(StockRules.expiryStatus(expiry: e, warnDays: 30, now: today, calendar: cal) == .ok(daysLeft: 94))
}

@Test func expiryBoundaryExactlyWarnDays() {
    // 警告日ちょうど(30日前)は警告に入る。31日前はまだ ok
    #expect(StockRules.expiryStatus(expiry: day(2026, 10, 28), warnDays: 30, now: today, calendar: cal) == .soon(daysLeft: 30))
    #expect(StockRules.expiryStatus(expiry: day(2026, 10, 29), warnDays: 30, now: today, calendar: cal) == .ok(daysLeft: 31))
}

@Test func expiryToday() {
    // 期限の当日は「あと0日」で、まだ切れていない
    #expect(StockRules.expiryStatus(expiry: today, warnDays: 30, now: today, calendar: cal) == .soon(daysLeft: 0))
}

@Test func expiryPassed() {
    #expect(StockRules.expiryStatus(expiry: day(2026, 9, 27), warnDays: 30, now: today, calendar: cal) == .expired(daysOver: 1))
}

// MARK: 要確認

@Test func attentionReasons() {
    #expect(entry().attention(now: today, calendar: cal).isEmpty)
    #expect(entry(remaining: 0.1).attention(now: today, calendar: cal) == [.low])
    #expect(entry(expiry: day(2026, 10, 1)).attention(now: today, calendar: cal) == [.expiringSoon(daysLeft: 3)])
    #expect(entry(expiry: day(2026, 9, 20)).attention(now: today, calendar: cal) == [.expired(daysOver: 8)])
    #expect(entry(remaining: 0.1, expiry: day(2026, 10, 1)).attention(now: today, calendar: cal).count == 2)
}

// MARK: 並び順

@Test func attentionComesFirstAndExpiredBeforeLow() {
    let fine = entry("A十分", remaining: 0.9)
    let low = entry("B少ない", remaining: 0.1)
    let expired = entry("C切れ", expiry: day(2026, 9, 20))
    let soon = entry("D近い", expiry: day(2026, 10, 3))
    let sections = StockSorter.sections([fine, soon, low, expired], now: today, calendar: cal)
    #expect(sections.attention.map(\.name) == ["C切れ", "B少ない", "D近い"])
    #expect(sections.others.map(\.name) == ["A十分"])
}

@Test func lowestRemainingFirstThenName() {
    let a = entry("あ", remaining: 0.6)
    let b = entry("い", remaining: 0.5)
    let c = entry("う", remaining: 0.5)
    let s = StockSorter.sections([a, c, b], now: today, calendar: cal)
    #expect(s.others.map(\.name) == ["い", "う", "あ"])
}

@Test func nonTrackingSortedByExpiryWithNoExpiryLast() {
    let none = entry("水", kind: .disaster, tracks: false, expiry: nil)
    let far = entry("缶詰", kind: .disaster, tracks: false, expiry: day(2027, 6, 1), warnDays: 90)
    let near = entry("電池", kind: .disaster, tracks: false, expiry: day(2027, 1, 1), warnDays: 90)
    let s = StockSorter.sections([none, far, near], now: today, calendar: cal)
    #expect(s.others.map(\.name) == ["電池", "缶詰", "水"])
}

@Test func trackingItemsComeBeforeNonTracking() {
    let t = entry("洗剤", remaining: 0.9)
    let n = entry("防災水", kind: .disaster, tracks: false)
    #expect(StockSorter.sections([n, t], now: today, calendar: cal).others.map(\.name) == ["洗剤", "防災水"])
}

// MARK: 通知の日時

@Test func alertDateIsWarnDaysBeforeAt9() {
    let d = StockRules.alertDate(expiry: day(2026, 12, 31), warnDays: 30, calendar: cal)
    #expect(d == day(2026, 12, 1, hour: 9))
    #expect(StockRules.alertDate(expiry: nil, warnDays: 30, calendar: cal) == nil)
}

// MARK: プリセット

@Test func presetsExistForEveryKind() {
    for kind in ItemKind.allCases {
        #expect(!Presets.categories(for: kind).isEmpty)
    }
}

@Test func disasterKitHasNoDuplicatesAndValidCategories() {
    let names = Presets.disasterKit.map(\.name)
    #expect(Set(names).count == names.count)
    let cats = Set(Presets.categories(for: .disaster))
    #expect(Presets.disasterKit.allSatisfy { cats.contains($0.category) })
}
