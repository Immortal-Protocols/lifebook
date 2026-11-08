import Foundation
import UserNotifications

/// Without a server, phones can't notify each other. So the *current* caregiver's own phone
/// nags them: 15 minutes before the session ends, at the end, and then every 15 minutes for
/// an hour until the handoff file has actually been sent.
enum Reminders {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func ids(for shiftId: UUID) -> [String] {
        (0..<6).map { "\(shiftId.uuidString)-\($0)" }
    }

    static func schedule(for shift: Shift, kidName: String, targetName: String, now: Date) {
        cancel(shiftId: shift.id)
        let center = UNUserNotificationCenter.current()
        let ids = ids(for: shift.id)

        var plan: [(Date, String, String)] = []
        if shift.isOpen {
            plan.append((shift.plannedEnd.addingTimeInterval(-15 * 60),
                         "15 minutes left",
                         "Log \(kidName)'s points so \(targetName) knows what happened."))
            plan.append((shift.plannedEnd,
                         "Time to hand off",
                         "Close out and send your notes to \(targetName)."))
        }
        let base = shift.isOpen ? shift.plannedEnd : (shift.closedAt ?? now)
        for i in 1...4 {
            plan.append((base.addingTimeInterval(TimeInterval(i * 15 * 60)),
                         "\(targetName) is waiting on you",
                         "\(targetName) can't start until your notes reach their phone. AirDrop or text the Lifebook file."))
        }

        for (i, item) in plan.enumerated() where i < ids.count {
            let (date, title, body) = item
            let interval = date.timeIntervalSince(now)
            guard interval > 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.add(UNNotificationRequest(identifier: ids[i], content: content, trigger: trigger))
        }
    }

    static func cancel(shiftId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids(for: shiftId))
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
