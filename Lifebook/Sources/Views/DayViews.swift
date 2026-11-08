import SwiftUI

// MARK: - Today (start of session)

struct DayView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let family = store.family!
        let me = store.me!
        let day = store.today
        let flags = Rules.flags(day: day, family: family)
        let gate = store.gate ?? .ready

        ScreenScaffold {
            Eyebrow(text: "\(family.kidName) · \(Fmt.weekday(store.now()))")
            Headline(text: headline(flags.count)).padding(.top, 10).padding(.bottom, 8)
            if let line = whatsNext(day: day, me: me, family: family, gate: gate) {
                Lede(text: line, size: 17, opacity: 0.6).padding(.bottom, 14)
            } else {
                Spacer().frame(height: 10)
            }

            SummaryGrid(points: family.points, day: day).padding(.bottom, 20)

            if flags.isEmpty {
                Text("Nothing flagged so far today.")
                    .font(.system(size: 19)).lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.vertical, 20)
                    .glass(22)
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(flags) { FlagBlock(flag: $0) }
                }
            }
        } bottom: {
            switch gate {
            case .resume:
                BigButton(title: "Back to my session", arrow: true) { store.route = .log }
            case .ready:
                BigButton(title: "Start my session", arrow: true, sheen: true) { store.route = .sessionSetup(withoutHandoffFrom: nil) }
            case .waitingOn:
                BigButton(title: "Start my session", arrow: true, sheen: true) { store.route = .blocked }
            }
        }
    }

    private func headline(_ n: Int) -> String {
        switch n {
        case 0: return "All quiet so far."
        case 1: return "One thing needs attention."
        default: return "\(n) things need attention."
        }
    }

    private func whatsNext(day: Day?, me: Member, family: Family, gate: Gate) -> String? {
        if case .resume = gate, let open = store.myOpenShift {
            return "You're on until \(Fmt.time(open.plannedEnd)), then \(family.member(open.handoffTo)?.firstName ?? "the next person")."
        }
        guard let last = day?.sortedShifts.last(where: { !$0.isOpen }) else {
            return me.isParent ? "You're first today. Start when you're with \(family.kidName)." : nil
        }
        let from = family.member(last.caregiverId)?.firstName ?? "Someone"
        let closed = last.closedAt.map(Fmt.time) ?? ""
        if last.handoffTo == me.id { return "\(from) handed off to you at \(closed)." }
        if last.caregiverId == me.id { return "You handed off to \(family.member(last.handoffTo)?.firstName ?? "someone") at \(closed)." }
        return "Last handoff: \(from) → \(family.member(last.handoffTo)?.firstName ?? "?") at \(closed)."
    }
}

struct SummaryGrid: View {
    let points: [String]
    let day: Day?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(points.enumerated()), id: \.element) { i, p in
                let latest = Rules.latest(point: p, day: day)
                let concern = latest?.mark == .concern
                VStack(spacing: 0) {
                    Group {
                        if latest == nil {
                            Image(systemName: Catalog.symbol(for: p)).foregroundStyle(Pearl.muted(0.35))
                        } else if concern {
                            Image(systemName: Catalog.symbol(for: p)).foregroundStyle(Pearl.crimson)
                        } else {
                            Image(systemName: "checkmark.circle").foregroundStyle(Pearl.green)
                        }
                    }
                    .font(.system(size: 24, weight: .regular))
                    .frame(height: 28)
                    Text(p).font(.system(size: 17, weight: .bold)).padding(.top, 8).lineLimit(1).minimumScaleFactor(0.7)
                    Text(latest == nil ? "Not logged" : concern ? "Watch" : "All good")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(concern ? Pearl.crimson : Pearl.muted())
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .overlay(alignment: .leading) {
                    if i > 0 { Rectangle().fill(Pearl.ink.opacity(0.1)).frame(width: 1) }
                }
            }
        }
        .padding(.vertical, 20)
        .glass(24, strong: true)
    }
}

struct FlagBlock: View {
    let flag: Flag
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: Catalog.symbol(for: flag.point))
                    .font(.system(size: 22, weight: .medium)).foregroundStyle(Pearl.crimson)
                Text(flag.point).font(.display(26)).tracking(-0.8)
                Spacer()
                Text("\((flag.by?.firstName ?? "?").uppercased()) · \(Fmt.time(flag.at))")
                    .font(.system(size: 12.5, weight: .bold)).tracking(1.2).foregroundStyle(Pearl.muted())
            }
            HStack(alignment: .top, spacing: 16) {
                Capsule().fill(Pearl.crimson).frame(width: 2)
                Text(flag.note).font(.system(size: 19)).lineSpacing(6).foregroundStyle(Pearl.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Session setup

struct SessionSetupView: View {
    @Environment(Store.self) private var store
    let editing: Bool
    let withoutHandoffFrom: UUID?

    @State private var hours = 4
    @State private var target: UUID?

    var body: some View {
        let family = store.family!
        let me = store.me!
        let start = editing ? (store.myOpenShift?.start ?? store.now()) : store.now()
        let end = start.addingTimeInterval(TimeInterval(hours * 3600))

        ScreenScaffold {
            Eyebrow(text: editing ? "Started at \(Fmt.time(start))" : "Starting at \(Fmt.time(start))")
            Headline(text: "How long are you on?", size: 36).padding(.top, 10).padding(.bottom, 8)
            Lede(text: "We'll remind you to close out 15 minutes before it ends.", size: 17).padding(.bottom, 18)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach([2, 4, 6, 8], id: \.self) { h in
                    Button { hours = h } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(h) hours").font(.display(24)).tracking(-0.7).foregroundStyle(Pearl.ink)
                            Text("until \(Fmt.time(start.addingTimeInterval(TimeInterval(h * 3600))))")
                                .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Pearl.muted(0.52))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18).padding(.vertical, 17)
                        .glass(20, on: hours == h)
                    }
                    .buttonStyle(PressStyle())
                }
            }

            SectionLabel(text: "Handing off to").padding(.top, 26).padding(.bottom, 12)
            VStack(spacing: 9) {
                ForEach(family.members.filter { $0.id != me.id }) { p in
                    PersonRow(member: p, on: target == p.id) { target = p.id }
                }
            }
            if withoutHandoffFrom != nil {
                Text("You're starting without \(family.member(withoutHandoffFrom)?.firstName ?? "the previous caregiver")'s notes. That's noted in today's log.")
                    .font(.system(size: 15.5)).foregroundStyle(Pearl.crimson).padding(.top, 16)
            }
        } bottom: {
            BigButton(title: target == nil ? "Pick who follows you" : (editing ? "Save · until \(Fmt.time(end))" : "Start · until \(Fmt.time(end))"),
                      enabled: target != nil) {
                guard let target else { return }
                Reminders.requestPermission()
                if editing { store.editSession(hours: hours, handoffTo: target) }
                else { store.startSession(hours: hours, handoffTo: target, withoutHandoffFrom: withoutHandoffFrom) }
            }
        }
        .onAppear {
            if editing, let open = store.myOpenShift {
                hours = max(1, Int((open.plannedEnd.timeIntervalSince(open.start) / 3600).rounded()))
                target = open.handoffTo
            } else {
                target = Rules.defaultTarget(me: me, family: family)
            }
        }
    }
}

// MARK: - Blocked

struct BlockedView: View {
    @Environment(Store.self) private var store
    @Binding var importing: Bool
    @State private var confirmSkip = false

    var body: some View {
        let family = store.family!
        let gate = store.gate ?? .ready
        let (waitId, kind): (UUID?, WaitKind) = {
            if case let .waitingOn(id, k) = gate { return (id, k) }
            return (nil, .notesFrom)
        }()
        let who = family.member(waitId)
        let name = who?.firstName ?? "The previous caregiver"
        let last = store.today?.sortedShifts.last
        let nudges = (store.today?.nudges ?? []).filter { $0.to == waitId }.sorted { $0.at < $1.at }

        ScreenScaffold {
            Eyebrow(text: "Can't start yet", color: Pearl.crimson)
            Headline(text: headline(kind, name), size: 36).padding(.top, 10).padding(.bottom, 12)
            Lede(text: explanation(kind, name, last: last, family: family), size: 18.5, opacity: 0.7)

            if !nudges.isEmpty {
                NoteCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(nudges) { n in
                            Text("\(Fmt.time(n.at)) — YOU NUDGED \(name.uppercased())")
                                .font(.system(size: 15.5, weight: .semibold)).tracking(0.6)
                                .foregroundStyle(Pearl.ink.opacity(0.75))
                                .padding(.vertical, 5)
                        }
                    }
                }
                .padding(.top, 22)
            }

            OutlineButton(title: "Nudge \(name)", weight: .bold) {
                guard let waitId else { return }
                let msg = "Hi \(name) — can you hand off \(family.kidName)'s Lifebook? I can't start until your notes come through. AirDrop it, or text me the file."
                Share.present([msg]) { sent in if sent { store.recordNudge(to: waitId) } }
            }
            .padding(.top, 16)

            OutlineButton(title: "I got the file — open it", weight: .bold) { importing = true }
                .padding(.top, 10)

            Lede(text: "Closing out is \(name)'s job, not yours. If they can't, you can start anyway — the parents will see that you started without their notes.",
                 size: 16, opacity: 0.55)
                .padding(.top, 20)

            Button { confirmSkip = true } label: {
                Text("Start without \(name)'s notes")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(Pearl.crimson)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Pearl.crimsonFill))
            }
            .buttonStyle(PressStyle())
            .padding(.top, 14)
        } bottom: {
            VStack(spacing: 14) {
                Text("Waiting on \(name)").font(.system(size: 17)).foregroundStyle(Pearl.muted(0.55))
                BigButton(title: "Start my session", enabled: false) {}
            }
        }
        .confirmationDialog("Start without \(name)'s notes?", isPresented: $confirmSkip, titleVisibility: .visible) {
            Button("Start anyway", role: .destructive) { store.route = .sessionSetup(withoutHandoffFrom: waitId) }
        } message: {
            Text("This is recorded in today's log for the parents.")
        }
        .onChange(of: store.gate) { _, g in
            if case .waitingOn = g {} else { store.route = .day }
        }
    }

    private func headline(_ kind: WaitKind, _ name: String) -> String {
        switch kind {
        case .notesFrom: return "\(name) hasn't handed off yet."
        case .openSession: return "\(name) hasn't finished their notes."
        case .dayStart: return "\(name) hasn't started the day."
        }
    }

    private func explanation(_ kind: WaitKind, _ name: String, last: Shift?, family: Family) -> String {
        switch kind {
        case .notesFrom:
            let at = last?.closedAt.map { " at \(Fmt.time($0))" } ?? ""
            let from = family.member(last?.caregiverId)?.firstName ?? "The last caregiver"
            return "\(from) handed off to \(name)\(at). \(name)'s notes haven't reached this phone, so you'd be starting blind. The day is paused here."
        case .openSession:
            return "\(name)'s session is still open. You'd be starting blind, so the day is paused here."
        case .dayStart:
            return "Parents start each day. Once \(name) hands off, their notes come to you by AirDrop or text."
        }
    }
}
