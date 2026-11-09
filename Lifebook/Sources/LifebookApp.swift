import SwiftUI
import UserNotifications

@main
struct LifebookApp: App {
    @State private var store: Store
    private let notificationDelegate = NotificationDelegate()

    init() {
        let args = ProcessInfo.processInfo.arguments
        let store = Store()
        #if DEBUG
        if args.contains("-resetState") { store.reset() }
        if let i = args.firstIndex(of: "-demo"), i + 1 < args.count {
            // e.g. -demo "Deb K." | -demo "Priya" | -demo "Marcus:first"
            let parts = args[i + 1].split(separator: ":")
            store.loadDemo(asMemberNamed: String(parts[0]), handoffChain: !parts.contains("first"))
        }
        if let i = args.firstIndex(of: "-importPath"), i + 1 < args.count {
            store.importFile(at: URL(fileURLWithPath: args[i + 1]))
        }
        if let i = args.firstIndex(of: "-meName"), i + 1 < args.count {
            store.setMe(store.family?.members.first { $0.name == args[i + 1] }?.id)
        }
        if let i = args.firstIndex(of: "-exportTo"), i + 1 < args.count, let url = store.makeFile() {
            try? FileManager.default.removeItem(atPath: args[i + 1])
            try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: args[i + 1]))
        }
        if let i = args.firstIndex(of: "-route"), i + 1 < args.count, store.me != nil, let family = store.family {
            switch args[i + 1] {
            case "blocked": store.route = .blocked
            case "join": store.setMe(nil)
            case "setup": store.route = .sessionSetup(withoutHandoffFrom: nil)
            case "log", "logConcern", "logDone", "handoff":
                if store.myOpenShift == nil { store.startSession(hours: 4) }
                if args[i + 1] != "log" {
                    store.setMark(family.points[0], .ok)
                    store.setMark(family.points[1], .concern)
                }
                if args[i + 1] == "logDone" || args[i + 1] == "handoff" {
                    store.setNote(family.points[1], "Still uncomfortable after dinner. Tried a warm bath; no BM yet.")
                    if family.points.count > 2 { store.setMark(family.points[2], .ok) }
                }
                if args[i + 1] == "handoff" { _ = store.closeSession() }
            case "digest": store.route = .digest(dayKey: store.todayKey)
            case "team": store.route = .team
            case "points": store.route = .points
            default: break
            }
        }
        #endif
        _store = State(initialValue: store)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onOpenURL { url in store.importFile(at: url) }
                .preferredColorScheme(.light)
        }
    }
}
