import Foundation
import StockCore
import UserNotifications

/// 期限の警告日の朝9時に、品目ごとに1回だけ通知する。すべてローカル通知で、通信はしない。
enum ExpiryNotifier {
    private static let prefix = "expiry-"
    /// iOS が保持できる予約は64件まで。近い順に入れる。
    private static let limit = 60

    struct Target {
        let id: UUID
        let name: String
        let expiry: Date?
        let warnDays: Int
    }

    /// 初めて期限を入れたときに呼ぶ。すでに答えがあれば聞き直さない。
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// 許可がなければ何もしない(ここでは許可を求めない)。
    static func reschedule(_ targets: [Target], enabled: Bool, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let cal = Calendar.current
        let upcoming = targets
            .compactMap { t -> (Target, Date)? in
                guard let expiry = t.expiry, let fire = StockRules.alertDate(expiry: expiry, warnDays: t.warnDays, calendar: cal),
                      fire > now else { return nil }
                return (t, fire)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)

        for (t, fire) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = "期限が近い品があります"
            content.body = "「\(t.name)」の期限は \(Fmt.date(t.expiry!)) です。"
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: prefix + t.id.uuidString, content: content, trigger: trigger))
        }
    }
}
