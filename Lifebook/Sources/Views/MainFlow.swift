import SwiftUI

struct MainFlow: View {
    @Environment(Store.self) private var store
    @State private var menu = false
    @State private var profile = false
    @State private var importing = false
    @State private var confirmLeave = false

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch store.route {
                case .day: DayView()
                case let .sessionSetup(without): SessionSetupView(editing: false, withoutHandoffFrom: without)
                case .editSession: SessionSetupView(editing: true, withoutHandoffFrom: nil)
                case .blocked: BlockedView(importing: $importing)
                case .log: LogView()
                case let .handoffDone(id): HandoffDoneView(shiftId: id)
                case let .digest(key): DigestView(dayKey: key)
                case .team: TeamView()
                case .points: PointsView()
                }
            }
            .transition(.opacity)

            if menu || profile {
                Color(red: 0.94, green: 0.93, blue: 0.94).opacity(menu ? 0.42 : 0.01)
                    .background(Material.ultraThin.opacity(menu ? 0.3 : 0))
                    .ignoresSafeArea()
                    .onTapGesture { menu = false; profile = false }
                    .transition(.opacity)
            }

            VStack(spacing: 6) {
                TopBar(onMenu: { withAnimation(.easeOut(duration: 0.18)) { menu.toggle(); profile = false } },
                       onProfile: { withAnimation(.easeOut(duration: 0.18)) { profile.toggle(); menu = false } })
                HStack(alignment: .top) {
                    if menu { mainMenu.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading))) }
                    Spacer()
                    if profile { profileMenu.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing))) }
                }
                .padding(.horizontal, 14)
            }
            .padding(.top, 4)
        }
        .animation(.easeInOut(duration: 0.2), value: store.route)
        .lifebookImporter($importing)
        .confirmationDialog("Remove \(store.family?.kidName ?? "this")'s Lifebook from this phone?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Remove from this phone", role: .destructive) { store.reset() }
        } message: {
            Text("Other phones keep their copies. You can rejoin by opening a Lifebook file.")
        }
    }

    private func go(_ r: Route) {
        withAnimation(.easeOut(duration: 0.18)) { menu = false; profile = false }
        store.route = r
    }

    private var mainMenu: some View {
        let family = store.family!
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(family.kidName.uppercased()) · CARE TEAM")
                .font(.system(size: 11.5, weight: .bold)).tracking(1.5).foregroundStyle(Pearl.muted(0.48))
                .padding(.horizontal, 10).padding(.vertical, 8)
            MenuRow(label: "Today", dot: Pearl.green) { go(store.myOpenShift != nil ? .log : .day) }
            MenuRow(label: "Care team & sharing") { go(.team) }
            MenuRow(label: "What we track") { go(.points) }
            MenuRow(label: "The day so far") { go(.digest(dayKey: store.todayKey)) }
            MenuRow(label: "Open a Lifebook file") { go(store.route); importing = true }
            MenuRow(label: "Remove from this phone", color: Pearl.crimson, dot: Pearl.crimson) {
                withAnimation { menu = false }
                confirmLeave = true
            }
        }
        .padding(10)
        .frame(width: 262)
        .glass(22, strong: true)
    }

    private var profileMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS PHONE LOGS AS")
                .font(.system(size: 11.5, weight: .bold)).tracking(1.5).foregroundStyle(Pearl.muted(0.48))
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)
            Text(store.me?.name ?? "")
                .font(.system(size: 17, weight: .bold)).padding(.horizontal, 10).padding(.bottom, 2)
            Text(store.me?.role ?? "")
                .font(.system(size: 14)).foregroundStyle(Pearl.muted()).padding(.horizontal, 10).padding(.bottom, 8)
            MenuRow(label: "Send today's log") {
                withAnimation { profile = false }
                if let url = store.makeFile() { Share.present([url]) }
            }
            MenuRow(label: "Switch person") {
                withAnimation { profile = false }
                store.setMe(nil)
            }
        }
        .padding(10)
        .frame(width: 232)
        .glass(22, strong: true)
    }
}

struct MenuRow: View {
    let label: String
    var color: Color = Pearl.ink
    var dot: Color = Pearl.ink.opacity(0.2)
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(label).font(.system(size: 16.5, weight: .semibold)).foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

struct TopBar: View {
    let onMenu: () -> Void
    let onProfile: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onMenu) {
                VStack(spacing: 5) {
                    Capsule().frame(width: 19, height: 2)
                    Capsule().frame(width: 19, height: 2)
                }
                .foregroundStyle(Pearl.ink)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Menu")
            .padding(.leading, -6)
            Text("Lifebook").font(.brand(27)).foregroundStyle(Pearl.ink)
            Spacer()
            Button(action: onProfile) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 25, weight: .light))
                    .foregroundStyle(Pearl.ink)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Who's logging")
        }
        .padding(.leading, 18).padding(.trailing, 8)
        .frame(height: 56)
        .glass(22, strong: true)
        .padding(.horizontal, 14)
    }
}
