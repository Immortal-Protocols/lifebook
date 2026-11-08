import SwiftUI

struct OnboardingFlow: View {
    enum Step { case welcome, kid, points, team }

    @Environment(Store.self) private var store
    @State private var step: Step = .welcome
    @State private var kid = ""
    @State private var picked: [String] = []
    @State private var myName = ""
    @State private var myRole = "Mom"
    @State private var others: [Member] = []
    @State private var importing = false

    var body: some View {
        Group {
            switch step {
            case .welcome: welcome
            case .kid: kidStep
            case .points: pointsStep
            case .team: teamStep
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .lifebookImporter($importing)
    }

    private var welcome: some View {
        ScreenScaffold(topPadding: 96) {
            BrandMark().padding(.bottom, 36)
            Eyebrow(text: "Welcome")
            Headline(text: "One day at a time, together.").padding(.vertical, 12)
            Lede(text: "No accounts, no servers. Lifebook lives on your family's phones and moves between them by AirDrop — or a text, in a pinch.")
                .padding(.bottom, 30)
            NoteCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CAREGIVER?").font(.system(size: 12.5, weight: .bold)).tracking(1.2).foregroundStyle(Pearl.crimson)
                    Text("Open the Lifebook file a parent AirDropped or texted you. It sets everything up.")
                        .font(.system(size: 17)).lineSpacing(4).foregroundStyle(Pearl.body)
                }
            }
        } bottom: {
            VStack(spacing: 12) {
                OutlineButton(title: "I have a Lifebook file") { importing = true }
                BigButton(title: "Set up for my kid", arrow: true, sheen: true) { step = .kid }
            }
        }
    }

    private var kidStep: some View {
        ScreenScaffold(topPadding: 96) {
            BackLink { step = .welcome }
            Eyebrow(text: "Setup · 1 of 3")
            Headline(text: "Who are we caring for?").padding(.vertical, 12)
            Lede(text: "First name is enough — it's what caregivers will see all day.").padding(.bottom, 30)
            TextFieldGlass(placeholder: "Nora", text: $kid)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .onSubmit { next() }
        } bottom: {
            BigButton(title: "Next", enabled: !kid.trimmed.isEmpty) { next() }
        }
    }

    private func next() {
        guard !kid.trimmed.isEmpty else { return }
        if picked.isEmpty { picked = Catalog.defaultPoints }
        step = .points
    }

    private var pointsStep: some View {
        ScreenScaffold(topPadding: 96) {
            BackLink { step = .kid }
            Eyebrow(text: "Setup · 2 of 3")
            Headline(text: "What should we track?", size: 34).padding(.top, 10).padding(.bottom, 8)
            Lede(text: "Up to three. Everyone logs exactly these — nothing to decide later.", size: 17).padding(.bottom, 16)
            PointPicker(picked: $picked)
        } bottom: {
            BigButton(title: "Next", enabled: !picked.isEmpty) { step = .team }
        }
    }

    private var teamStep: some View {
        ScreenScaffold(topPadding: 96) {
            BackLink { step = .points }
            Eyebrow(text: "Setup · 3 of 3")
            Headline(text: "Who's on the care team?", size: 34).padding(.top, 10).padding(.bottom, 8)
            Lede(text: "Everyone who takes a shift with \(kid.trimmed). You'll send them the Lifebook file next.", size: 17)
                .padding(.bottom, 22)

            SectionLabel(text: "You").padding(.bottom, 10)
            TextFieldGlass(placeholder: "Your first name", text: $myName, size: 18)
                .textInputAutocapitalization(.words)
            HStack(spacing: 8) {
                ForEach(["Mom", "Dad", "Parent"], id: \.self) { r in
                    Button { myRole = r } label: {
                        Text(r).font(.system(size: 16, weight: myRole == r ? .bold : .medium))
                            .foregroundStyle(myRole == r ? Pearl.ink : Pearl.ink.opacity(0.6))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .glass(99, on: myRole == r)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.top, 10)

            SectionLabel(text: "Caregivers & co-parents").padding(.top, 26).padding(.bottom, 10)
            MemberEditor(members: $others)
        } bottom: {
            BigButton(title: "Next", enabled: !myName.trimmed.isEmpty, arrow: true) {
                let me = Member(name: myName.trimmed, role: "\(myRole) · parent", isParent: true)
                store.createFamily(kidName: kid.trimmed, points: picked, me: me, others: others)
            }
        }
    }
}

struct BackLink: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                Text("Back").font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Pearl.muted(0.55))
        }
        .padding(.bottom, 18)
    }
}

struct PointPicker: View {
    @Binding var picked: [String]
    var editable: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Catalog.all, id: \.name) { c in
                let on = picked.contains(c.name)
                let full = picked.count >= Catalog.maxPoints && !on
                Button {
                    guard editable else { return }
                    if let i = picked.firstIndex(of: c.name) { picked.remove(at: i) }
                    else if picked.count < Catalog.maxPoints { picked.append(c.name) }
                } label: {
                    HStack(spacing: 13) {
                        CheckBox(on: on)
                        Text(c.name).font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(full ? Pearl.ink.opacity(0.35) : Pearl.ink)
                        Spacer()
                        Image(systemName: c.symbol).font(.system(size: 17)).foregroundStyle(Pearl.muted(0.4))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 15)
                    .glass(19, on: on)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .disabled(!editable)
            }
            Text("\(picked.count) of \(Catalog.maxPoints) chosen")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Pearl.muted(0.55))
                .padding(.top, 5).padding(.leading, 2)
        }
    }
}

struct MemberEditor: View {
    @Binding var members: [Member]
    @State private var name = ""
    @State private var role = ""
    @State private var isParent = false

    var body: some View {
        VStack(spacing: 9) {
            ForEach(members) { m in
                HStack(spacing: 13) {
                    Text(m.initials).font(.system(size: 14.5, weight: .bold)).foregroundStyle(Pearl.ink.opacity(0.6))
                        .frame(width: 34, height: 34).background(Circle().fill(Pearl.ink.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.name).font(.system(size: 17.5, weight: .semibold))
                        Text(m.role).font(.system(size: 14)).foregroundStyle(Pearl.muted())
                    }
                    Spacer()
                    Button { members.removeAll { $0.id == m.id } } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Pearl.muted(0.45))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Remove \(m.name)")
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .glass(19)
            }

            VStack(spacing: 0) {
                TextField("Name", text: $name)
                    .font(.system(size: 17.5, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                Divider().opacity(0.5).padding(.horizontal, 16)
                TextField(isParent ? "e.g. Dad" : "e.g. Weekday caregiver", text: $role)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16).padding(.vertical, 14)
                Divider().opacity(0.5).padding(.horizontal, 16)
                HStack {
                    Toggle(isOn: $isParent) {
                        Text("Parent").font(.system(size: 16, weight: .medium)).foregroundStyle(Pearl.ink.opacity(0.7))
                    }
                    .toggleStyle(.switch).tint(Pearl.green).fixedSize()
                    Spacer()
                    Button {
                        let n = name.trimmed
                        guard !n.isEmpty else { return }
                        let r = role.trimmed.isEmpty ? (isParent ? "Parent" : "Caregiver") : role.trimmed
                        members.append(Member(name: n, role: isParent ? "\(r) · parent" : r, isParent: isParent))
                        name = ""; role = ""; isParent = false
                    } label: {
                        Text("Add").font(.system(size: 16, weight: .bold))
                            .foregroundStyle(name.trimmed.isEmpty ? Pearl.ink.opacity(0.3) : Pearl.ink)
                            .padding(.horizontal, 18).padding(.vertical, 9)
                            .glass(99, on: !name.trimmed.isEmpty)
                    }
                    .buttonStyle(PressStyle())
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            .glass(19, on: false)
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
