import Foundation

// MARK: - Core data

struct Member: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var role: String
    var isParent: Bool

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        return letters.joined().isEmpty ? "?" : letters.joined()
    }
}

struct Family: Codable, Hashable {
    var id: UUID = UUID()
    var kidName: String
    /// Up to three data points, set by the parents.
    var points: [String]
    var members: [Member]
    var updatedAt: Date = Date()

    func member(_ id: UUID?) -> Member? {
        guard let id else { return nil }
        return members.first { $0.id == id }
    }

    var parents: [Member] { members.filter(\.isParent) }
}

enum Mark: String, Codable, Hashable {
    case ok
    case concern
}

struct Entry: Codable, Hashable {
    var mark: Mark
    var note: String = ""
    var at: Date = Date()
    /// Each "+1" tap: when the thing happened (a BM, a nap, a dose…).
    var times: [Date] = []

    init(mark: Mark, note: String = "", at: Date = Date(), times: [Date] = []) {
        self.mark = mark
        self.note = note
        self.at = at
        self.times = times
    }

    // Files from builds before "+1" have no `times`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mark = try c.decode(Mark.self, forKey: .mark)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        at = try c.decodeIfPresent(Date.self, forKey: .at) ?? Date()
        times = try c.decodeIfPresent([Date].self, forKey: .times) ?? []
    }
}

struct Shift: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var caregiverId: UUID
    var start: Date
    var plannedEnd: Date
    var closedAt: Date?
    var entries: [String: Entry] = [:]
    /// Set when the caregiver started without the previous caregiver's notes.
    var startedWithoutHandoffFrom: UUID?
    var updatedAt: Date = Date()

    var isOpen: Bool { closedAt == nil }

    func isComplete(points: [String]) -> Bool {
        points.allSatisfy { p in
            guard let e = entries[p] else { return false }
            return e.mark == .ok || e.note.trimmingCharacters(in: .whitespacesAndNewlines).count > 3
        }
    }

    func hasConcern(points: [String]) -> Bool {
        points.contains { entries[$0]?.mark == .concern }
    }
}

struct Nudge: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var at: Date
    var by: UUID
    var to: UUID
}

struct Day: Codable, Identifiable, Hashable {
    /// Local calendar date, yyyy-MM-dd.
    var id: String
    var shifts: [Shift] = []
    var nudges: [Nudge] = []

    var sortedShifts: [Shift] { shifts.sorted { $0.start < $1.start } }
}

/// The file that moves between phones by AirDrop / Messages.
struct LifebookFile: Codable {
    var format: String = "lifebook"
    var version: Int = 1
    var family: Family
    var days: [Day]
    var sentBy: UUID?
    var sentAt: Date = Date()
}

struct LocalState: Codable {
    var family: Family?
    var days: [String: Day] = [:]
    var meId: UUID?
    /// Shifts whose handoff file was shared successfully from this phone.
    var sentShiftIds: Set<UUID> = []
}

// MARK: - Dates

enum DayKey {
    static func of(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

enum Fmt {
    static func time(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    static func shortTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: d)
    }

    static func weekday(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    static func longDay(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: d)
    }

    static func fileDay(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM-d"
        return f.string(from: d)
    }
}

// MARK: - Catalog

struct CatalogPoint: Hashable {
    let name: String
    let symbol: String
    /// Gets a "+1" button: something that happens a number of times.
    var countable: Bool = true
}

enum Catalog {
    static let all: [CatalogPoint] = [
        .init(name: "Meds", symbol: "pills"),
        .init(name: "BM", symbol: "drop"),
        .init(name: "Nap", symbol: "moon"),
        .init(name: "Meals", symbol: "fork.knife"),
        .init(name: "Mood", symbol: "face.smiling", countable: false),
        .init(name: "Seizure activity", symbol: "waveform.path.ecg"),
    ]

    static func symbol(for point: String) -> String {
        all.first { $0.name == point }?.symbol ?? "circle.dashed"
    }

    static func isCountable(_ point: String) -> Bool {
        all.first { $0.name == point }?.countable ?? true
    }

    static let defaultPoints = ["Meds", "BM", "Nap"]
    static let maxPoints = 3
}
