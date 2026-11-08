import Foundation
import Observation
import UniformTypeIdentifiers

extension UTType {
    static let lifebook = UTType(exportedAs: "app.lifebook.handoff", conformingTo: .json)
}

enum Route: Equatable {
    case day
    case sessionSetup(withoutHandoffFrom: UUID?)
    case editSession
    case blocked
    case log
    case handoffDone(shiftId: UUID)
    case digest(dayKey: String)
    case team
    case points
}

struct Notice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@Observable
final class Store {
    private(set) var state: LocalState
    var route: Route = .day
    var notice: Notice?
    /// An incoming file from a different family, waiting for the user to confirm replacement.
    var pendingReplacement: LifebookFile?

    private let fileURL: URL
    var now: () -> Date = Date.init

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Store.defaultURL
        self.fileURL = url
        if let data = try? Data(contentsOf: url),
           let s = try? Codec.decoder.decode(LocalState.self, from: data) {
            state = s
        } else {
            state = LocalState()
        }
    }

    static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("lifebook-state.json")
    }

    private func save() {
        if let data = try? Codec.encoder.encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func mutate(_ body: (inout LocalState) -> Void) {
        body(&state)
        save()
    }

    // MARK: Derived

    var family: Family? { state.family }
    var me: Member? { family?.member(state.meId) }
    var todayKey: String { DayKey.of(now()) }
    var today: Day? { state.days[todayKey] }

    var gate: Gate? {
        guard let me, let family else { return nil }
        return Rules.gate(day: today, me: me, family: family)
    }

    var myOpenShift: Shift? {
        guard let me else { return nil }
        return today?.shifts.first { $0.caregiverId == me.id && $0.isOpen }
    }

    func shift(_ id: UUID) -> Shift? {
        for day in state.days.values {
            if let s = day.shifts.first(where: { $0.id == id }) { return s }
        }
        return nil
    }

    func wasSent(_ shiftId: UUID) -> Bool { state.sentShiftIds.contains(shiftId) }

    var pastDayKeys: [String] { state.days.keys.sorted(by: >) }

    // MARK: Setup

    func createFamily(kidName: String, points: [String], me: Member, others: [Member]) {
        let fam = Family(kidName: kidName, points: Array(points.prefix(Catalog.maxPoints)), members: [me] + others)
        mutate {
            $0 = LocalState(family: fam, days: [:], meId: me.id, sentShiftIds: [])
        }
        route = .team
    }

    func setMe(_ id: UUID?) {
        mutate { $0.meId = id }
        route = .day
    }

    func updatePoints(_ points: [String]) {
        mutate {
            $0.family?.points = Array(points.prefix(Catalog.maxPoints))
            $0.family?.updatedAt = now()
        }
    }

    func addMember(_ m: Member) {
        mutate {
            $0.family?.members.append(m)
            $0.family?.updatedAt = now()
        }
    }

    func removeMember(_ id: UUID) {
        guard id != state.meId else { return }
        mutate {
            $0.family?.members.removeAll { $0.id == id }
            $0.family?.updatedAt = now()
        }
    }

    func reset() {
        if let open = myOpenShift { Reminders.cancel(shiftId: open.id) }
        mutate { $0 = LocalState() }
        route = .day
    }

    // MARK: Sessions

    private func updateToday(_ body: (inout Day) -> Void) {
        let key = todayKey
        mutate {
            var day = $0.days[key] ?? Day(id: key)
            body(&day)
            $0.days[key] = day
        }
    }

    @discardableResult
    func startSession(hours: Int, handoffTo: UUID, withoutHandoffFrom: UUID? = nil) -> Shift? {
        guard let me else { return nil }
        let start = now()
        let shift = Shift(
            caregiverId: me.id,
            start: start,
            plannedEnd: start.addingTimeInterval(TimeInterval(hours * 3600)),
            handoffTo: handoffTo,
            startedWithoutHandoffFrom: withoutHandoffFrom,
            updatedAt: start
        )
        updateToday { $0.shifts.append(shift) }
        scheduleReminders(for: shift)
        route = .log
        return shift
    }

    func editSession(hours: Int, handoffTo: UUID) {
        guard let open = myOpenShift else { return }
        updateShift(open.id) {
            $0.plannedEnd = $0.start.addingTimeInterval(TimeInterval(hours * 3600))
            $0.handoffTo = handoffTo
        }
        if let s = shift(open.id) { scheduleReminders(for: s) }
        route = .log
    }

    private func updateShift(_ id: UUID, _ body: (inout Shift) -> Void) {
        mutate { st in
            for (key, var day) in st.days {
                if let i = day.shifts.firstIndex(where: { $0.id == id }) {
                    body(&day.shifts[i])
                    day.shifts[i].updatedAt = now()
                    st.days[key] = day
                    return
                }
            }
        }
    }

    func setMark(_ point: String, _ mark: Mark) {
        guard let open = myOpenShift else { return }
        updateShift(open.id) { s in
            var e = s.entries[point] ?? Entry(mark: mark)
            e.mark = mark
            e.at = now()
            s.entries[point] = e
        }
    }

    func setNote(_ point: String, _ note: String) {
        guard let open = myOpenShift else { return }
        updateShift(open.id) { s in
            var e = s.entries[point] ?? Entry(mark: .concern)
            e.note = note
            e.at = now()
            s.entries[point] = e
        }
    }

    /// Close the session. The caller then shares the file.
    func closeSession(handoffTo: UUID) -> UUID? {
        guard let open = myOpenShift, let family, open.isComplete(points: family.points) else { return nil }
        updateShift(open.id) {
            $0.closedAt = now()
            $0.handoffTo = handoffTo
        }
        if let closed = shift(open.id) { scheduleReminders(for: closed) }
        route = .handoffDone(shiftId: open.id)
        return open.id
    }

    func markSent(_ shiftId: UUID) {
        mutate { _ = $0.sentShiftIds.insert(shiftId) }
        Reminders.cancel(shiftId: shiftId)
    }

    func recordNudge(to: UUID) {
        guard let me else { return }
        updateToday { $0.nudges.append(Nudge(at: now(), by: me.id, to: to)) }
    }

    private func scheduleReminders(for shift: Shift) {
        guard let family, !state.sentShiftIds.contains(shift.id) else { return }
        let target = family.member(shift.handoffTo)?.firstName ?? "the next caregiver"
        Reminders.schedule(for: shift, kidName: family.kidName, targetName: target, now: now())
    }

    // MARK: Exchange

    /// Writes the current family + recent days to a temp .lifebook file for sharing.
    func makeFile() -> URL? {
        guard let family else { return nil }
        let recent = state.days.keys.sorted(by: >).prefix(7).compactMap { state.days[$0] }
        let file = LifebookFile(family: family, days: recent, sentBy: state.meId, sentAt: now())
        guard let data = try? Codec.encoder.encode(file) else { return nil }
        let who = me.map { "-from-\($0.firstName)" } ?? ""
        let name = "\(family.kidName)-\(Fmt.fileDay(now()))\(who)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("outgoing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name).appendingPathExtension("lifebook")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func importFile(at url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            importData(data)
        } catch {
            notice = Notice(title: "Couldn't open that file", message: error.localizedDescription)
        }
        // Clean up AirDrop inbox copies.
        if url.path.contains("/Inbox/") { try? FileManager.default.removeItem(at: url) }
    }

    func importData(_ data: Data) {
        do {
            let file = try Codec.decode(data)
            apply(file, replacing: false)
        } catch {
            notice = Notice(title: "Couldn't open that file", message: error.localizedDescription)
        }
    }

    func confirmReplacement() {
        guard let file = pendingReplacement else { return }
        pendingReplacement = nil
        if let open = myOpenShift { Reminders.cancel(shiftId: open.id) }
        apply(file, replacing: true)
    }

    private func apply(_ file: LifebookFile, replacing: Bool) {
        let (newState, outcome) = Merge.apply(file, to: state, replacingFamily: replacing)
        switch outcome {
        case .differentFamily:
            pendingReplacement = file
            return
        case .joined:
            state = newState
            save()
            route = .day
        case let .merged(added, updated):
            state = newState
            save()
            let from = file.family.member(file.sentBy)?.firstName ?? "another phone"
            let total = added + updated
            let msg = total == 0
                ? "Nothing new — this phone was already up to date."
                : "\(total) session\(total == 1 ? "" : "s") from \(from) added to \(file.family.kidName)'s day."
            notice = Notice(title: "Notes received", message: msg)
            if case .handoffDone = route {} else if route == .blocked { route = .day }
        }
    }

    // MARK: Demo data (DEBUG / screenshots)

    func loadDemo(asMemberNamed name: String = "Deb K.", handoffChain: Bool = true) {
        let priya = Member(name: "Priya", role: "Mom · parent", isParent: true)
        let ana = Member(name: "Ana R.", role: "Weekday caregiver", isParent: false)
        let deb = Member(name: "Deb K.", role: "Evenings", isParent: false)
        let marcus = Member(name: "Marcus", role: "Dad · parent", isParent: true)
        let fam = Family(kidName: "Nora", points: ["Meds", "BM", "Nap"], members: [priya, ana, deb, marcus])
        let cal = Calendar.current
        let base = cal.startOfDay(for: now())
        func at(_ h: Int, _ m: Int) -> Date { base.addingTimeInterval(TimeInterval(h * 3600 + m * 60)) }
        let s1 = Shift(caregiverId: priya.id, start: at(6, 0), plannedEnd: at(8, 0), handoffTo: ana.id, closedAt: at(8, 10),
                       entries: ["Meds": Entry(mark: .ok, at: at(7, 0)), "BM": Entry(mark: .ok, at: at(7, 30)), "Nap": Entry(mark: .ok, at: at(8, 0))])
        let s2 = Shift(caregiverId: ana.id, start: at(8, 10), plannedEnd: at(14, 30), handoffTo: deb.id, closedAt: at(14, 35),
                       entries: ["Meds": Entry(mark: .ok, at: at(12, 0)),
                                 "BM": Entry(mark: .concern, note: "Only once since 8am and she seemed uncomfortable around noon. Gave extra water. Worth watching this afternoon.", at: at(12, 24)),
                                 "Nap": Entry(mark: .ok, at: at(13, 30))])
        var day = Day(id: DayKey.of(now()))
        day.shifts = handoffChain ? [s1, s2] : [s1]
        let meId = fam.members.first { $0.name == name }?.id
        mutate { $0 = LocalState(family: fam, days: [day.id: day], meId: meId, sentShiftIds: [s1.id, s2.id]) }
        route = .day
    }
}
