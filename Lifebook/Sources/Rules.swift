import Foundation

/// Can this person start a session right now?
enum Gate: Equatable {
    /// They already have an open session on this phone.
    case resume(shiftId: UUID)
    case ready
    case waitingOn(memberId: UUID, kind: WaitKind)
}

enum WaitKind: Equatable {
    /// Someone's session is known to still be open; their notes haven't reached this phone.
    case openSession
    /// No notes from today have reached this phone yet. Parents start each day.
    case dayStart
}

struct Flag: Hashable, Identifiable {
    var id: String { "\(shiftId)-\(point)" }
    let shiftId: UUID
    let point: String
    let by: Member?
    let at: Date
    let note: String
}

enum Rules {
    /// Principle: it's the current caregiver's job to hand off. Handoffs are just files, so there's
    /// no "who's next": a caregiver can start once today's latest notes are on their phone.
    /// Parents control the agenda and are never blocked.
    static func gate(day: Day?, me: Member, family: Family) -> Gate {
        let shifts = day?.sortedShifts ?? []
        if let open = shifts.last(where: { $0.caregiverId == me.id && $0.isOpen }) {
            return .resume(shiftId: open.id)
        }
        if me.isParent { return .ready }

        guard let last = shifts.last else {
            if let parent = family.parents.first { return .waitingOn(memberId: parent.id, kind: .dayStart) }
            return .ready
        }
        if last.isOpen { return .waitingOn(memberId: last.caregiverId, kind: .openSession) }
        return .ready
    }

    static func flags(day: Day?, family: Family) -> [Flag] {
        guard let day else { return [] }
        var out: [Flag] = []
        for shift in day.sortedShifts {
            for p in family.points {
                if let e = shift.entries[p], e.mark == .concern {
                    out.append(Flag(shiftId: shift.id, point: p, by: family.member(shift.caregiverId), at: e.at, note: e.note))
                }
            }
        }
        return out
    }

    /// The most recent mark for each point today.
    static func latest(point: String, day: Day?) -> Entry? {
        guard let day else { return nil }
        for shift in day.sortedShifts.reversed() {
            if let e = shift.entries[point] { return e }
        }
        return nil
    }
}

// MARK: - Merge

enum Merge {
    enum Outcome: Equatable {
        case joined
        case merged(newShifts: Int, updatedShifts: Int)
        case differentFamily
    }

    /// Merge an incoming file into local state. Pure; returns the new state.
    static func apply(_ file: LifebookFile, to local: LocalState, replacingFamily: Bool = false) -> (LocalState, Outcome) {
        var state = local

        if let fam = state.family, fam.id != file.family.id, !replacingFamily {
            return (state, .differentFamily)
        }

        let joining = state.family == nil || state.family?.id != file.family.id
        if joining {
            state = LocalState(family: file.family, days: [:], meId: nil, sentShiftIds: [])
        } else if let fam = state.family {
            // Kid name and points: newest wins. People: everyone either phone has seen.
            var merged = file.family.updatedAt > fam.updatedAt ? file.family : fam
            merged.members = fam.members
            for m in file.family.members where !merged.members.contains(where: { $0.id == m.id }) {
                merged.members.append(m)
            }
            state.family = merged
        }

        var added = 0, updated = 0
        for incoming in file.days {
            var day = state.days[incoming.id] ?? Day(id: incoming.id)
            for shift in incoming.shifts {
                if let i = day.shifts.firstIndex(where: { $0.id == shift.id }) {
                    let mine = day.shifts[i]
                    if prefer(shift, over: mine) {
                        day.shifts[i] = shift
                        updated += 1
                    }
                } else {
                    day.shifts.append(shift)
                    added += 1
                }
            }
            let knownNudges = Set(day.nudges.map(\.id))
            day.nudges += incoming.nudges.filter { !knownNudges.contains($0.id) }
            state.days[incoming.id] = day
        }

        return (state, joining ? .joined : .merged(newShifts: added, updatedShifts: updated))
    }

    static func prefer(_ a: Shift, over b: Shift) -> Bool {
        if a.closedAt != nil && b.closedAt == nil { return true }
        if a.closedAt == nil && b.closedAt != nil { return false }
        return a.updatedAt > b.updatedAt
    }
}

// MARK: - Codec

enum Codec {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    enum CodecError: LocalizedError {
        case notLifebook
        var errorDescription: String? { "That file isn't a Lifebook handoff." }
    }

    static func decode(_ data: Data) throws -> LifebookFile {
        guard let file = try? decoder.decode(LifebookFile.self, from: data), file.format == "lifebook" else {
            throw CodecError.notLifebook
        }
        return file
    }
}
