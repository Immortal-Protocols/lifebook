import SwiftUI

// MARK: - Logging

struct LogView: View {
    @Environment(Store.self) private var store
    @State private var confirmClose = false

    var body: some View {
        if let shift = store.myOpenShift, let family = store.family {
            content(shift: shift, family: family)
        } else {
            DayView()
        }
    }

    private func content(shift: Shift, family: Family) -> some View {
        let points = family.points
        let logged = points.filter { shift.entries[$0] != nil }.count
        let complete = shift.isComplete(points: points)
        let missing = points.filter { shift.entries[$0] == nil }
        let needNote = points.filter { shift.entries[$0]?.mark == .concern && (shift.entries[$0]?.note.trimmed.count ?? 0) <= 3 }
        let hours = Int((shift.plannedEnd.timeIntervalSince(shift.start) / 3600).rounded())

        return ScreenScaffold(topPadding: 80) {
            HStack(alignment: .firstTextBaseline) {
                Headline(text: "Your shift", size: 34)
                Spacer()
                Text("SINCE \(Fmt.time(shift.start))").font(.system(size: 12.5, weight: .bold)).tracking(1.5).foregroundStyle(Pearl.muted(0.6))
            }
            HStack(spacing: 8) {
                Text("\(hours)h · ends \(Fmt.time(shift.plannedEnd))")
                Button("Change") { store.route = .editSession }
                    .foregroundStyle(Pearl.ink).underline()
            }
            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Pearl.muted())
            .padding(.top, 2).padding(.bottom, 4)

            ForEach(points, id: \.self) { p in
                PointRow(point: p, entry: shift.entries[p])
                Divider().overlay(Pearl.ink.opacity(0.1))
            }
        } bottom: {
            VStack(spacing: 14) {
                Text(hint(complete: complete, needNote: needNote, missing: missing))
                    .font(.system(size: 17)).foregroundStyle(Pearl.muted(0.6))
                    .multilineTextAlignment(.center)
                Button {
                    guard complete else { return }
                    confirmClose = true
                } label: {
                    Text("Hand off · \(logged) of \(points.count)")
                        .font(.display(21)).tracking(-0.5)
                        .foregroundStyle(complete ? Pearl.ink : Pearl.ink.opacity(0.62))
                        .frame(maxWidth: .infinity).padding(24)
                        .background(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(complete ? AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.98), .white.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.6)))
                                    .frame(width: geo.size.width * CGFloat(logged) / CGFloat(max(points.count, 1)))
                                    .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45), value: logged)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .glass(26, on: true)
                }
                .buttonStyle(PressStyle())
            }
        }
        .confirmationDialog("Close your shift?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Close & send my notes") {
                guard let id = store.closeSession() else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { sendHandoff(id) }
            }
        } message: {
            Text("Next, AirDrop the file to whoever's taking over — or text it if they're not nearby.")
        }
    }

    private func sendHandoff(_ id: UUID) {
        guard let url = store.makeFile() else { return }
        Share.present([url]) { sent in if sent { store.markSent(id) } }
    }

    private func hint(complete: Bool, needNote: [String], missing: [String]) -> String {
        if complete { return "Close out, then AirDrop or text your notes" }
        if !needNote.isEmpty { return "Write what you saw for \(needNote.joined(separator: ", "))" }
        return "Log \(missing.map { $0.lowercased() }.joined(separator: ", ")) to continue"
    }
}

struct PointRow: View {
    @Environment(Store.self) private var store
    let point: String
    let entry: Entry?
    @State private var note: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        let mark = entry?.mark
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: Catalog.symbol(for: point))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(mark == .concern ? Pearl.crimson : Color(red: 0.23, green: 0.22, blue: 0.25))
                    .frame(width: 28)
                Text(point).font(.display(24)).tracking(-0.7).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                HStack(spacing: 2) {
                    segment("All good", on: mark == .ok, concern: false) { store.setMark(point, .ok); focused = false }
                    segment("Concern", on: mark == .concern, concern: true) {
                        store.setMark(point, .concern)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focused = true }
                    }
                }
                .padding(4)
                .frame(width: 206)
                .glass(18)
            }
            if mark == .concern {
                NoteCard {
                    TextField("What did you see? The next caregiver reads this first.", text: $note, axis: .vertical)
                        .font(.system(size: 18)).lineSpacing(4)
                        .foregroundStyle(Pearl.body)
                        .lineLimit(3...)
                        .focused($focused)
                        .onChange(of: note) { _, v in store.setNote(point, v) }
                }
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 16).padding(.bottom, 20)
        .animation(.easeOut(duration: 0.2), value: mark)
        .onAppear { note = entry?.note ?? "" }
    }

    private func segment(_ title: String, on: Bool, concern: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: on ? .bold : .medium))
                .foregroundStyle(on ? (concern ? Pearl.crimson : Pearl.ink) : Pearl.ink.opacity(0.62))
                .frame(maxWidth: .infinity).frame(height: 46)
                .background {
                    if on {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(concern ? AnyShapeStyle(Pearl.crimsonFill) : AnyShapeStyle(Color.white))
                            .shadow(color: (concern ? Color(red: 90 / 255, green: 20 / 255, blue: 35 / 255) : Color(red: 40 / 255, green: 34 / 255, blue: 60 / 255)).opacity(0.14), radius: 6, y: 4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Handoff done

struct HandoffDoneView: View {
    @Environment(Store.self) private var store
    let shiftId: UUID
    @State private var pop = false

    var body: some View {
        let points = store.family?.points ?? []
        let shift = store.shift(shiftId)
        let sent = store.wasSent(shiftId)

        ScreenScaffold(topPadding: 170) {
            ZStack {
                Circle().stroke(Pearl.green, lineWidth: 2)
                    .scaleEffect(pop ? 2.4 : 0.55).opacity(pop ? 0 : 0.5)
                Circle().fill(.white.opacity(0.9))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                    .shadow(color: Color(red: 40 / 255, green: 34 / 255, blue: 60 / 255).opacity(0.14), radius: 18, y: 16)
                Image(systemName: "checkmark").font(.system(size: 38, weight: .bold)).foregroundStyle(Pearl.green)
            }
            .frame(width: 92, height: 92)
            .scaleEffect(pop ? 1 : 0.5)
            .padding(.bottom, 30)

            Headline(text: sent ? "Shift closed.\nNotes sent." : "Shift closed.\nNow send your notes.", size: 38)
            if let shift {
                Lede(text: points.map { "\($0) \(shift.entries[$0]?.mark == .concern ? "flagged" : "normal")" }.joined(separator: " · ") + ".",
                     size: 19, opacity: 0.65)
                    .padding(.top, 14)
            }

            if sent {
                Label("Notes sent. Reminders are off.", systemImage: "paperplane")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Pearl.green)
                    .padding(.top, 24)
                OutlineButton(title: "Send again") { send() }.padding(.top, 14)
            } else {
                NoteCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOT SENT YET").font(.system(size: 12.5, weight: .bold)).tracking(1.2).foregroundStyle(Pearl.crimson)
                        Text("The next caregiver can't start until your notes reach their phone. We'll keep reminding you.")
                            .font(.system(size: 17)).lineSpacing(4).foregroundStyle(Pearl.body)
                    }
                }
                .padding(.top, 24)
                OutlineButton(title: "AirDrop or text my notes", weight: .bold) { send() }.padding(.top, 12)
            }
        } bottom: {
            BigButton(title: "See the day") { store.route = .digest(dayKey: store.todayKey) }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = true }
        }
    }

    private func send() {
        guard let url = store.makeFile() else { return }
        Share.present([url]) { sent in if sent { store.markSent(shiftId) } }
    }
}
