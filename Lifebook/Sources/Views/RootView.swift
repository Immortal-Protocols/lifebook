import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        ZStack {
            PearlBackground()
            if store.family == nil {
                OnboardingFlow()
            } else if store.me == nil {
                JoinView()
            } else {
                MainFlow()
            }
        }
        .alert(item: $store.notice) { n in
            Alert(title: Text(n.title), message: Text(n.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "This file is for \(store.pendingReplacement?.family.kidName ?? "another family")",
            isPresented: Binding(get: { store.pendingReplacement != nil }, set: { if !$0 { store.pendingReplacement = nil } }),
            titleVisibility: .visible
        ) {
            Button("Switch to \(store.pendingReplacement?.family.kidName ?? "it")", role: .destructive) { store.confirmReplacement() }
            Button("Keep \(store.family?.kidName ?? "current")", role: .cancel) { store.pendingReplacement = nil }
        } message: {
            Text("This phone can follow one kid at a time. Switching replaces \(store.family?.kidName ?? "the current")'s log on this phone.")
        }
    }
}

/// File-picker hook shared by several screens.
struct ImportFileModifier: ViewModifier {
    @Environment(Store.self) private var store
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.fileImporter(isPresented: $isPresented, allowedContentTypes: [.lifebook, .json]) { result in
            if case let .success(url) = result { store.importFile(at: url) }
        }
    }
}

extension View {
    func lifebookImporter(_ isPresented: Binding<Bool>) -> some View {
        modifier(ImportFileModifier(isPresented: isPresented))
    }
}

// MARK: - Who are you?

/// Shown after opening a Lifebook file for the first time (or after "Switch person").
/// Just a name — no one has to have added you first.
struct JoinView: View {
    @Environment(Store.self) private var store
    @State private var name = ""
    @State private var isParent = false
    @FocusState private var focused: Bool

    var body: some View {
        let family = store.family
        let kid = family?.kidName ?? "the kid"
        ScreenScaffold(topPadding: 96) {
            BrandMark().padding(.bottom, 36)
            Eyebrow(text: "\(kid) · care team")
            Headline(text: "What's your name?", size: 38).padding(.top, 12).padding(.bottom, 12)
            Lede(text: "Your notes go out under this name. This phone logs as you from now on.")
                .padding(.bottom, 24)
            TextFieldGlass(placeholder: "First name", text: $name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(join)
                .accessibilityIdentifier("joinName")
            Toggle(isOn: $isParent) {
                Text("I'm \(kid)'s parent").font(.system(size: 17, weight: .medium)).foregroundStyle(Pearl.ink.opacity(0.75))
            }
            .tint(Pearl.green)
            .padding(.horizontal, 6).padding(.top, 16)

            if let members = family?.members, !members.isEmpty {
                SectionLabel(text: "Already on the team? Tap your name").padding(.top, 30).padding(.bottom, 10)
                VStack(spacing: 9) {
                    ForEach(members) { m in
                        PersonRow(member: m, on: false) { store.setMe(m.id) }
                    }
                }
            }
        } bottom: {
            BigButton(title: name.trimmed.isEmpty ? "Type your name" : "I'm \(name.trimmed)", enabled: !name.trimmed.isEmpty, arrow: true, action: join)
        }
    }

    private func join() { store.join(name: name, isParent: isParent) }
}

struct BrandMark: View {
    var body: some View {
        Text("Lifebook").font(.brand(34)).foregroundStyle(Pearl.ink)
    }
}
