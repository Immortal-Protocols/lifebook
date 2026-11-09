import SwiftUI

struct OnboardingFlow: View {
    enum Step { case welcome, kid, points, team }

    @Environment(Store.self) private var store
    @State private var step: Step = .welcome
    @State private var kid = ""
    @State private var picked: [String] = []
    @State private var myName = ""
    @State private var myRole = "Mom"
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
                    Text("Open the Lifebook file someone AirDropped or texted you, then type your name. That's it.")
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
            Headline(text: "And you are?", size: 34).padding(.top, 10).padding(.bottom, 8)
            Lede(text: "No need to list the care team. Send the Lifebook file to whoever's on and they join when they open it.", size: 17)
                .padding(.bottom, 22)

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
        } bottom: {
            BigButton(title: "Next", enabled: !myName.trimmed.isEmpty, arrow: true) {
                let me = Member(name: myName.trimmed, role: "\(myRole) · parent", isParent: true)
                store.createFamily(kidName: kid.trimmed, points: picked, me: me)
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

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
