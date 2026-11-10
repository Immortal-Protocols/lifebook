import XCTest
@testable import Lifebook

final class RulesTests: XCTestCase {
    let priya = Member(name: "Priya", role: "Mom · parent", isParent: true)
    let ana = Member(name: "Ana R.", role: "Weekday caregiver", isParent: false)
    let deb = Member(name: "Deb K.", role: "Evenings", isParent: false)
    lazy var family = Family(kidName: "Nora", points: ["Meds", "BM", "Nap"], members: [priya, ana, deb])

    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func shift(_ who: Member, closed: Bool, offsetHours: Double = 0, entries: [String: Entry] = [:]) -> Shift {
        let start = t0.addingTimeInterval(offsetHours * 3600)
        return Shift(caregiverId: who.id, start: start, plannedEnd: start.addingTimeInterval(7200),
                     closedAt: closed ? start.addingTimeInterval(7000) : nil, entries: entries, updatedAt: start)
    }

    func testCaregiverWaitsForParentsAtDayStart() {
        XCTAssertEqual(Rules.gate(day: nil, me: deb, family: family), .waitingOn(memberId: priya.id, kind: .dayStart))
    }

    func testParentsAreNeverBlocked() {
        var day = Day(id: "d")
        day.shifts = [shift(ana, closed: true)]
        XCTAssertEqual(Rules.gate(day: day, me: priya, family: family), .ready)
        XCTAssertEqual(Rules.gate(day: nil, me: priya, family: family), .ready)
    }

    func testReadyOnceAnyoneElsesNotesArrive() {
        // No "who's next": whoever has today's latest closed notes on their phone can start.
        var day = Day(id: "d")
        day.shifts = [shift(priya, closed: true)]
        XCTAssertEqual(Rules.gate(day: day, me: deb, family: family), .ready)
        day.shifts.append(shift(ana, closed: true, offsetHours: 2))
        XCTAssertEqual(Rules.gate(day: day, me: deb, family: family), .ready)
    }

    func testCaregiverWithNoFamilyParentIsNotStuck() {
        let solo = Family(kidName: "Nora", points: ["Meds"], members: [deb])
        XCTAssertEqual(Rules.gate(day: nil, me: deb, family: solo), .ready)
    }

    func testBlockedByKnownOpenSession() {
        var day = Day(id: "d")
        day.shifts = [shift(ana, closed: false)]
        XCTAssertEqual(Rules.gate(day: day, me: deb, family: family), .waitingOn(memberId: ana.id, kind: .openSession))
    }

    func testResumeOwnOpenSession() {
        var day = Day(id: "d")
        let mine = shift(deb, closed: false)
        day.shifts = [shift(ana, closed: true), mine]
        XCTAssertEqual(Rules.gate(day: day, me: deb, family: family), .resume(shiftId: mine.id))
    }

    func testStartingWithoutNotesUnblocks() {
        var day = Day(id: "d")
        let mine = shift(deb, closed: true, offsetHours: 3)
        day.shifts = [shift(ana, closed: false), mine]
        XCTAssertEqual(Rules.gate(day: day, me: deb, family: family), .ready)
    }

    func testCompletenessRequiresNoteForConcern() {
        var s = shift(ana, closed: false)
        s.entries = ["Meds": Entry(mark: .ok), "BM": Entry(mark: .concern), "Nap": Entry(mark: .ok)]
        XCTAssertFalse(s.isComplete(points: family.points))
        s.entries["BM"]?.note = "Hard, once since 8am"
        XCTAssertTrue(s.isComplete(points: family.points))
        s.entries["Nap"] = nil
        XCTAssertFalse(s.isComplete(points: family.points))
    }

    func testFlagsAndLatest() {
        var day = Day(id: "d")
        day.shifts = [
            shift(priya, closed: true, entries: ["BM": Entry(mark: .ok)]),
            shift(ana, closed: true, offsetHours: 2, entries: ["BM": Entry(mark: .concern, note: "uncomfortable")]),
        ]
        let flags = Rules.flags(day: day, family: family)
        XCTAssertEqual(flags.count, 1)
        XCTAssertEqual(flags.first?.by?.id, ana.id)
        XCTAssertEqual(Rules.latest(point: "BM", day: day)?.mark, .concern)
        XCTAssertNil(Rules.latest(point: "Nap", day: day))
    }
}

final class MergeTests: XCTestCase {
    let priya = Member(name: "Priya", role: "Mom · parent", isParent: true)
    let ana = Member(name: "Ana R.", role: "Weekday caregiver", isParent: false)
    lazy var family = Family(kidName: "Nora", points: ["Meds"], members: [priya, ana])

    func testJoiningAdoptsFamilyAndAsksIdentity() {
        let file = LifebookFile(family: family, days: [], sentBy: priya.id)
        let (state, outcome) = Merge.apply(file, to: LocalState())
        XCTAssertEqual(outcome, .joined)
        XCTAssertEqual(state.family?.id, family.id)
        XCTAssertNil(state.meId)
    }

    func testDifferentFamilyNeedsConfirmation() {
        let local = LocalState(family: family, days: [:], meId: priya.id)
        let other = Family(kidName: "Max", points: ["Meds"], members: [priya])
        let (state, outcome) = Merge.apply(LifebookFile(family: other, days: []), to: local)
        XCTAssertEqual(outcome, .differentFamily)
        XCTAssertEqual(state.family?.kidName, "Nora")

        let (replaced, o2) = Merge.apply(LifebookFile(family: other, days: []), to: local, replacingFamily: true)
        XCTAssertEqual(o2, .joined)
        XCTAssertEqual(replaced.family?.kidName, "Max")
    }

    func testShiftsUnionAndClosedWins() {
        let t = Date()
        let open = Shift(caregiverId: ana.id, start: t, plannedEnd: t, closedAt: nil, updatedAt: t.addingTimeInterval(100))
        var closed = open
        closed.closedAt = t
        closed.updatedAt = t
        closed.entries = ["Meds": Entry(mark: .ok)]
        let other = Shift(caregiverId: priya.id, start: t.addingTimeInterval(-3600), plannedEnd: t, closedAt: t)

        let local = LocalState(family: family, days: ["d": Day(id: "d", shifts: [open])], meId: priya.id)
        let file = LifebookFile(family: family, days: [Day(id: "d", shifts: [closed, other], nudges: [Nudge(at: t, by: priya.id, to: ana.id)])])
        let (state, outcome) = Merge.apply(file, to: local)
        XCTAssertEqual(outcome, .merged(newShifts: 1, updatedShifts: 1))
        XCTAssertEqual(state.days["d"]?.shifts.count, 2)
        XCTAssertNotNil(state.days["d"]?.shifts.first { $0.id == open.id }?.closedAt)
        XCTAssertEqual(state.days["d"]?.nudges.count, 1)
        XCTAssertEqual(state.meId, priya.id)

        // Re-importing the same file is a no-op.
        let (again, o2) = Merge.apply(file, to: state)
        XCTAssertEqual(o2, .merged(newShifts: 0, updatedShifts: 0))
        XCTAssertEqual(again.days["d"]?.nudges.count, 1)
    }

    func testNewerFamilyWins() {
        var newer = family
        newer.points = ["Meds", "Nap"]
        newer.updatedAt = family.updatedAt.addingTimeInterval(60)
        let local = LocalState(family: family, days: [:], meId: ana.id)
        let (state, _) = Merge.apply(LifebookFile(family: newer, days: []), to: local)
        XCTAssertEqual(state.family?.points, ["Meds", "Nap"])

        // Older doesn't overwrite.
        let (state2, _) = Merge.apply(LifebookFile(family: family, days: []), to: state)
        XCTAssertEqual(state2.family?.points, ["Meds", "Nap"])
    }

    func testMembersAreUnionedEvenWhenOlderFileArrives() {
        // Deb joined on her own phone; her handoff file reaches Priya, whose family record is newer.
        let deb = Member(name: "Deb K.", role: "Caregiver", isParent: false)
        var debsCopy = family
        debsCopy.members.append(deb)
        var priyasCopy = family
        priyasCopy.points = ["Meds", "Nap"]
        priyasCopy.updatedAt = family.updatedAt.addingTimeInterval(60)
        let local = LocalState(family: priyasCopy, days: [:], meId: priya.id)
        let (state, _) = Merge.apply(LifebookFile(family: debsCopy, days: [], sentBy: deb.id), to: local)
        XCTAssertEqual(state.family?.points, ["Meds", "Nap"])
        XCTAssertEqual(state.family?.members.map(\.name), ["Priya", "Ana R.", "Deb K."])
        XCTAssertEqual(state.meId, priya.id)
    }
}

final class CodecTests: XCTestCase {
    func testRoundTrip() throws {
        let p = Member(name: "Priya", role: "Mom", isParent: true)
        let fam = Family(kidName: "Nora", points: ["BM"], members: [p])
        let shift = Shift(caregiverId: p.id, start: Date(), plannedEnd: Date(), entries: ["BM": Entry(mark: .concern, note: "once")])
        let file = LifebookFile(family: fam, days: [Day(id: "2026-11-08", shifts: [shift])], sentBy: p.id)
        let data = try Codec.encoder.encode(file)
        let back = try Codec.decode(data)
        XCTAssertEqual(back.family.kidName, "Nora")
        XCTAssertEqual(back.days.first?.shifts.first?.entries["BM"]?.note, "once")
        // Human-readable JSON, so it survives being texted.
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"format\" : \"lifebook\""))
    }

    func testOldFilesWithoutCountsStillOpen() throws {
        let json = #"{"mark":"concern","note":"hard","at":"2026-11-08T12:00:00Z"}"#
        let e = try Codec.decoder.decode(Entry.self, from: Data(json.utf8))
        XCTAssertEqual(e.note, "hard")
        XCTAssertEqual(e.times, [])
    }

    func testPlusOneCountsAndTravels() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let a = Store(fileURL: url)
        a.loadDemo(asMemberNamed: "Deb K.")
        let before = Rules.times(point: "BM", day: a.today).count
        a.startSession(hours: 2)
        a.tally("BM")
        a.tally("BM")
        a.untally("BM")
        XCTAssertEqual(a.myOpenShift?.entries["BM"]?.times.count, 1)
        XCTAssertEqual(a.myOpenShift?.entries["BM"]?.mark, .ok) // +1 logs the point
        a.setMark("BM", .concern)
        a.tally("BM")
        XCTAssertEqual(a.myOpenShift?.entries["BM"]?.mark, .concern) // +1 doesn't clear a concern
        XCTAssertEqual(Rules.times(point: "BM", day: a.today).count, before + 2)

        let other = Store(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        other.importFile(at: a.makeFile()!)
        XCTAssertEqual(Rules.times(point: "BM", day: other.today).count, before + 2)
    }

    func testRejectsOtherJSON() {
        XCTAssertThrowsError(try Codec.decode(Data(#"{"hello":"world"}"#.utf8)))
    }

    func testStorePersistsAcrossLaunches() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let a = Store(fileURL: url)
        a.loadDemo(asMemberNamed: "Deb K.")
        XCTAssertEqual(a.gate, .ready)
        a.startSession(hours: 4)
        a.setMark("Meds", .ok)
        a.setMark("BM", .concern)
        a.setNote("BM", "Still uncomfortable after dinner")
        a.setMark("Nap", .ok)

        let b = Store(fileURL: url)
        XCTAssertEqual(b.myOpenShift?.entries["BM"]?.note, "Still uncomfortable after dinner")
        XCTAssertNotNil(b.closeSession())
        XCTAssertNil(b.myOpenShift)

        // The exported file brings Priya's phone up to date.
        let fileURL = b.makeFile()!
        let priyaPhone = Store(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        priyaPhone.importFile(at: fileURL)
        XCTAssertEqual(priyaPhone.family?.kidName, "Nora")
        XCTAssertNil(priyaPhone.me) // asks who they are
        priyaPhone.setMe(priyaPhone.family!.parents[0].id)
        XCTAssertEqual(Rules.flags(day: priyaPhone.today, family: priyaPhone.family!).count, 2)
    }

    func testNewPhoneJoinsWithJustAName() {
        let parent = Store(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        parent.createFamily(kidName: "Nora", points: ["Meds"], me: Member(name: "Priya", role: "Mom · parent", isParent: true))
        let file = parent.makeFile()!

        let sam = Store(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        sam.importFile(at: file)
        XCTAssertNil(sam.me)
        sam.join(name: "  Sam ", isParent: false)
        XCTAssertEqual(sam.me?.name, "Sam")
        XCTAssertEqual(sam.family?.members.count, 2)
        // Priya hasn't started today, so Sam waits on her.
        XCTAssertEqual(sam.gate, .waitingOn(memberId: parent.me!.id, kind: .dayStart))

        // Same name again (e.g. reinstall) reuses the existing person.
        sam.setMe(nil)
        sam.join(name: "sam", isParent: false)
        XCTAssertEqual(sam.family?.members.count, 2)

        // Sam's handoff teaches Priya's phone who Sam is.
        parent.startSession(hours: 2)
        parent.setMark("Meds", .ok)
        _ = parent.closeSession()
        sam.importFile(at: parent.makeFile()!)
        XCTAssertEqual(sam.gate, .ready)
        sam.startSession(hours: 2)
        sam.setMark("Meds", .ok)
        _ = sam.closeSession()
        parent.importFile(at: sam.makeFile()!)
        XCTAssertEqual(parent.family?.members.map(\.name), ["Priya", "Sam"])
        XCTAssertEqual(parent.today?.shifts.count, 2)
    }
}
