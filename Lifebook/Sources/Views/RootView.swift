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
                WhoAreYouView()
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

struct WhoAreYouView: View {
    @Environment(Store.self) private var store
    @State private var picked: UUID?

    var body: some View {
        let family = store.family!
        ScreenScaffold(topPadding: 96) {
            BrandMark().padding(.bottom, 36)
            Eyebrow(text: "\(family.kidName) · care team")
            Headline(text: "Which one is you?", size: 38).padding(.top, 12).padding(.bottom, 12)
            Lede(text: "This phone will log as you. Not on the list? Ask \(family.parents.first?.firstName ?? "a parent") to add you and send a fresh file.")
                .padding(.bottom, 24)
            VStack(spacing: 9) {
                ForEach(family.members) { m in
                    PersonRow(member: m, on: picked == m.id) { picked = m.id }
                }
            }
        } bottom: {
            BigButton(title: "That's me", enabled: picked != nil, arrow: true) { store.setMe(picked) }
        }
    }
}

struct BrandMark: View {
    var body: some View {
        Text("Lifebook").font(.brand(34)).foregroundStyle(Pearl.ink)
    }
}
