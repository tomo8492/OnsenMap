import Foundation
import UserNotifications
import CoreLocation

// MARK: - Notification Service
actor NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await scheduleWeeklyReminder()
    }

    var isAuthorized: Bool {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Badge Unlock Notification
    func scheduleBadgeUnlock(_ badge: Badge) async {
        guard await isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🎉 バッジ解放！「\(badge.name)」"
        content.body  = badge.description
        content.sound = .default
        content.badge = 1

        // 即時通知（2秒後）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "badge_\(badge.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Weekly Reminder（毎週日曜 10:00）
    func scheduleWeeklyReminder() async {
        guard await isAuthorized else { return }

        // 既存の週次リマインダーを削除してから再スケジュール
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["weekly_reminder"]
        )

        let messages = [
            "今週はどの温泉に行きましたか？♨️",
            "週末は温泉でリフレッシュしよう！",
            "新しい温泉を発見してみませんか？",
            "行きたいリストの温泉、今週こそ行ってみよう！",
            "温泉記録を更新して称号を上げよう🏆",
        ]

        let content = UNMutableNotificationContent()
        content.title = "OnsenMap"
        content.body  = messages.randomElement() ?? messages[0]
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // 日曜日
        dateComponents.hour   = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly_reminder",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Nearby Onsen Notification（位置情報トリガー）
    func scheduleNearbyNotification(
        for onsenName: String,
        at coordinate: CLLocationCoordinate2D,
        radius: Double = 500
    ) async {
        guard await isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "近くに温泉があります！♨️"
        content.body  = "\(onsenName) が近くにあります。立ち寄ってみませんか？"
        content.sound = .default

        let region = CLCircularRegion(
            center: coordinate,
            radius: radius,
            identifier: "onsen_\(onsenName)"
        )
        region.notifyOnEntry = true
        region.notifyOnExit  = false

        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
        let request = UNNotificationRequest(
            identifier: "nearby_\(onsenName)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel All
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
