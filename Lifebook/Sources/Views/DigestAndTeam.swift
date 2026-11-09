import SwiftUI

// MARK: - The day (digest)

struct DigestView: View {
    @Environment(Store.self) private var store
    let dayKey: String

    var body: some View {
        if let family = store.family { content(family: family) }
    }

    private func content(family: Family) -> some View {
        let day = store.state.days[dayKey]
        let flags = Rules.flags(day: day, family: family)
        let shifts = day?.sortedShifts ?? []
        let date = DayKey.date(dayKey) ?? store.now()
        let isToday = dayKey == store.todayKey
        let weekday = Fmt.weekday(date)
        let skipped = shifts.filter { $0.startedWithoutHandoffFrom != nil }

        return ScreenScaffold {
            if store.pastDayKeys.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.pastDayKeys, id: \.self) { k in
                            let d = DayKey.date(k) ?? store.now()
                            Button { store.route = .digest(dayKey: k) } label: {
                                Text(k == store.todayKey ? "Today" : Fmt.longDay(d))
                                    .font(.system(size: 14.5, weight: k == dayKey ? .bold : .medium))
                                    .foregroundStyle(k == dayKey ? Pearl.ink : Pearl.muted(0.6))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .glass(99, on: k == dayKey)
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.bottom, 14)
            }

            Eyebrow(text: isToday ? "Today · \(weekday)" : Fmt.longDay(date))
            Headline(text: flags.isEmpty ? "A quiet \(weekday)." : "\(Array(Set(flags.map(\.point))).sorted().joined(separator: ", ")), flagged \(isToday ? "today" : "").".replacingOccurrences(of: " .", with: "."), size: 36)
                .padding(.top, 10).padding(.bottom, 6)
            Text("\(Set(shifts.map(\.caregiverId)).count) caregiver\(Set(shifts.map(\.caregiverId)).count == 1 ? "" : "s") · \(flags.count) flag\(flags.count == 1 ? "" : "s")")
                .font(.system(size: 17)).foregroundStyle(Pearl.muted(0.6)).padding(.bottom, 18)

            VStack(spacing: 10) {
                ForEach(flags) { f in
                    NoteCard {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("\(f.point.uppercased()) · \((f.by?.firstName ?? "?").uppercased()) · \(Fmt.time(f.at))")
                                .font(.system(size: 12.5, weight: .bold)).tracking(1.2).foregroundStyle(Pearl.crimson)
                            Text(f.note).font(.system(size: 18)).lineSpacing(5).foregroundStyle(Pearl.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ForEach(skipped) { s in
                    NoteCard {
                        Text("\(family.member(s.caregiverId)?.firstName ?? "Someone") started at \(Fmt.time(s.start)) without \(family.member(s.startedWithoutHandoffFrom)?.firstName ?? "the previous caregiver")'s notes.")
                            .font(.system(size: 17)).lineSpacing(4).foregroundStyle(Pearl.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            VStack(spacing: 0) {
                if shifts.isEmpty {
                    Text("No sessions logged on this phone yet.")
                        .font(.system(size: 17)).foregroundStyle(Pearl.muted(0.55)).padding(.vertical, 15)
                }
                ForEach(shifts) { s in
                    let bad = family.points.filter { s.entries[$0]?.mark == .concern }.count
                    HStack(spacing: 12) {
                        Text("\(Fmt.shortTime(s.start))–\(s.closedAt.map(Fmt.shortTime) ?? "now")")
                            .font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Pearl.muted())
                            .frame(width: 96, alignment: .leading)
                        Text(family.member(s.caregiverId)?.name ?? "Someone").font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Text(s.isOpen ? "in progress" : bad > 0 ? "\(bad) flag\(bad == 1 ? "" : "s")" : "all normal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(bad > 0 ? Pearl.crimson : Pearl.muted())
                    }
                    .padding(.vertical, 15)
                    .overlay(alignment: .bottom) { Rectangle().fill(Pearl.ink.opacity(0.1)).frame(height: 1) }
                }
            }
            .padding(.top, 16)
        } bottom: {
            BigButton(title: store.myOpenShift != nil ? "Back to my session" : "Back to today") {
                store.route = store.myOpenShift != nil ? .log : .day
            }
        }
    }
}

// MARK: - Care team & sharing

struct TeamView: View {
    @Environment(Store.self) private var store
    @State private var sent = false

    var body: some View {
        if let family = store.family, let me = store.me { content(family: family, me: me) }
    }

    private func content(family: Family, me: Member) -> some View {
        ScreenScaffold {
            Eyebrow(text: "\(family.kidName) · care team")
            Headline(text: me.isParent ? "Send it to whoever's on." : "The care team.", size: 36).padding(.top, 12).padding(.bottom, 10)
            Lede(text: "AirDrop this file to anyone taking a shift, or text it in a pinch. They open it, type their name, and they're in — no accounts, no list to keep.", size: 17.5)
                .padding(.bottom, 22)

            HStack(spacing: 14) {
                Image(systemName: "doc.richtext").font(.system(size: 26, weight: .light)).foregroundStyle(Pearl.ink.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(family.kidName).lifebook").font(.system(size: 17, weight: .bold))
                    Text(family.points.joined(separator: ", "))
                        .font(.system(size: 14.5)).foregroundStyle(Pearl.muted())
                }
                Spacer()
            }
            .padding(18)
            .glass(20)

            OutlineButton(title: sent ? "Sent — share again" : "Share via AirDrop or Messages", weight: .bold) {
                if let url = store.makeFile() { Share.present([url]) { ok in if ok { sent = true } } }
            }
            .padding(.top, 12)

            SectionLabel(text: "Who's joined").padding(.top, 26).padding(.bottom, 4)
            Text("People show up here once their notes reach this phone.")
                .font(.system(size: 15)).foregroundStyle(Pearl.muted(0.55)).padding(.bottom, 10)
            VStack(spacing: 9) {
                ForEach(family.members) { m in
                    HStack(spacing: 13) {
                        Text(m.initials).font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(m.id == me.id ? .white : Pearl.ink.opacity(0.6))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(m.id == me.id ? Pearl.green : Pearl.ink.opacity(0.08)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.id == me.id ? "\(m.name) (you)" : m.name).font(.system(size: 17.5, weight: .semibold))
                            Text(m.role).font(.system(size: 14)).foregroundStyle(Pearl.muted())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .glass(19)
                }
            }

            SectionLabel(text: "Tracking for \(family.kidName)").padding(.top, 26).padding(.bottom, 10)
            HStack(spacing: 8) {
                ForEach(family.points, id: \.self) { Pill(text: $0) }
            }
        } bottom: {
            BigButton(title: "Done — open today", arrow: true) {
                store.route = store.myOpenShift != nil ? .log : .day
            }
        }
    }
}

// MARK: - What we track

struct PointsView: View {
    @Environment(Store.self) private var store
    @State private var picked: [String] = []

    var body: some View {
        if let family = store.family { content(family: family) }
    }

    private func content(family: Family) -> some View {
        let isParent = store.me?.isParent ?? false
        let changed = picked != family.points

        return ScreenScaffold {
            Eyebrow(text: "\(family.kidName) · tracking")
            Headline(text: "What we track", size: 34).padding(.top, 10).padding(.bottom, 8)
            Lede(text: isParent
                 ? "Up to three. Change them here, then send the file to the team so everyone logs the same points."
                 : "Mom and Dad choose these. Everyone logs exactly the same points.", size: 17)
                .padding(.bottom, 16)
            PointPicker(picked: $picked, editable: isParent)
        } bottom: {
            if isParent {
                BigButton(title: changed ? "Save & share with team" : "Done", enabled: !picked.isEmpty) {
                    if changed {
                        store.updatePoints(picked)
                        if let url = store.makeFile() { Share.present([url]) }
                    }
                    store.route = store.myOpenShift != nil ? .log : .day
                }
            } else {
                BigButton(title: "Done") { store.route = store.myOpenShift != nil ? .log : .day }
            }
        }
        .onAppear { picked = family.points }
    }
}
