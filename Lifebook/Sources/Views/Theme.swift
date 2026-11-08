import SwiftUI
import UIKit

// Colors translated from the Pearl design's oklch tokens.
enum Pearl {
    static let ink = Color(red: 0x1C / 255, green: 0x1B / 255, blue: 0x1F / 255)
    static let body = Color(red: 0x26 / 255, green: 0x24 / 255, blue: 0x2A / 255)
    static let crimson = Color(red: 0x8E / 255, green: 0x2B / 255, blue: 0x3E / 255)   // oklch(0.45 0.14 15)
    static let crimsonFill = Color(red: 0xF8 / 255, green: 0xE4 / 255, blue: 0xE6 / 255) // oklch(0.945 0.035 15)
    static let green = Color(red: 0x2F / 255, green: 0x7D / 255, blue: 0x53 / 255)     // oklch(0.52 0.11 155)
    static func muted(_ o: Double = 0.5) -> Color { ink.opacity(o) }
}

extension Font {
    /// Bricolage Grotesque ExtraBold (variable font, wght 800, optical size tracks point size).
    static func display(_ size: CGFloat) -> Font {
        let wght = 0x7767_6874 // 'wght'
        let opsz = 0x6F70_737A // 'opsz'
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let desc = UIFontDescriptor(fontAttributes: [.family: "Bricolage Grotesque"])
            .addingAttributes([variation: [wght: 800, opsz: min(max(size, 12), 96)]])
        return Font(UIFont(descriptor: desc, size: size))
    }

    static func brand(_ size: CGFloat) -> Font { .custom("InstrumentSerif-Regular", size: size) }
}

// MARK: Background

struct PearlBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Color(red: 0.988, green: 0.984, blue: 0.984), Color(red: 0.961, green: 0.957, blue: 0.965)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(red: 0.99, green: 0.93, blue: 0.93), .clear], center: UnitPoint(x: 0.1, y: 0.02), startRadius: 0, endRadius: w * 0.9)
                RadialGradient(colors: [Color(red: 0.97, green: 0.92, blue: 0.97), .clear], center: UnitPoint(x: 0.94, y: 0.16), startRadius: 0, endRadius: w * 0.85)
                RadialGradient(colors: [Color(red: 0.90, green: 0.97, blue: 0.93), .clear], center: UnitPoint(x: 0.82, y: 0.92), startRadius: 0, endRadius: w * 0.95)
                RadialGradient(colors: [Color(red: 0.92, green: 0.92, blue: 0.99), .clear], center: UnitPoint(x: 0.02, y: 0.78), startRadius: 0, endRadius: w * 0.85)
                // Concentric pearl rings, bottom left.
                ZStack {
                    ForEach(0..<13) { i in
                        Circle().stroke(Color.white.opacity(0.85), lineWidth: 2)
                            .frame(width: CGFloat(34 + i * 60), height: CGFloat(34 + i * 60))
                    }
                }
                .frame(width: 760, height: 760)
                .mask(RadialGradient(colors: [.black.opacity(0.55), .black.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 380 * 0.72 * 1.4))
                .position(x: -120 + 380, y: h + 320 - 380)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: Glass

struct Glass: ViewModifier {
    var radius: CGFloat = 20
    var on: Bool = true
    var strong: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(on ? 0.6 : 0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: on
                                ? [.white.opacity(strong ? 0.96 : 0.9), .white.opacity(strong ? 0.66 : 0.58), .white.opacity(strong ? 0.86 : 0.78)]
                                : [.white.opacity(0.5), .white.opacity(0.24)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(on ? Color.white.opacity(0.95) : Pearl.ink.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 40 / 255, green: 34 / 255, blue: 60 / 255).opacity(on ? (strong ? 0.13 : 0.09) : 0), radius: strong ? 17 : 13, y: strong ? 16 : 10)
            )
    }
}

extension View {
    func glass(_ radius: CGFloat = 20, on: Bool = true, strong: Bool = false) -> some View {
        modifier(Glass(radius: radius, on: on, strong: strong))
    }
}

// MARK: Type helpers

struct Eyebrow: View {
    let text: String
    var color: Color = Pearl.ink
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(color)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12.5, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Pearl.muted())
    }
}

struct Headline: View {
    let text: String
    var size: CGFloat = 38
    var body: some View {
        Text(text)
            .font(.display(size))
            .tracking(-size * 0.035)
            .lineSpacing(0)
            .foregroundStyle(Pearl.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Lede: View {
    let text: String
    var size: CGFloat = 18
    var opacity: Double = 0.62
    var body: some View {
        Text(text)
            .font(.system(size: size))
            .lineSpacing(size * 0.3)
            .foregroundStyle(Pearl.ink.opacity(opacity))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Buttons

struct BigButton: View {
    let title: String
    var enabled: Bool = true
    var arrow: Bool = false
    var sheen: Bool = false
    let action: () -> Void

    @State private var sheenX: CGFloat = -1.3

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 14) {
                Text(title)
                if arrow {
                    Image(systemName: "arrow.right").font(.system(size: 19, weight: .bold))
                }
            }
            .font(.display(21))
            .tracking(-0.5)
            .foregroundStyle(enabled ? Pearl.ink : Pearl.ink.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .glass(26, on: enabled, strong: true)
            .overlay {
                if sheen && enabled {
                    GeometryReader { geo in
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.9), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.36)
                            .offset(x: geo.size.width * sheenX)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.7).delay(3.5).repeatForever(autoreverses: false)) { sheenX = 2.4 }
                    }
                }
            }
        }
        .buttonStyle(PressStyle())
    }
}

struct OutlineButton: View {
    let title: String
    var weight: Font.Weight = .semibold
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: weight))
                .foregroundStyle(Pearl.ink)
                .frame(maxWidth: .infinity)
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Pearl.ink.opacity(0.14), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: Rows

struct CheckBox: View {
    let on: Bool
    var round: Bool = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: round ? 11 : 9, style: .continuous)
                .fill(on ? Pearl.green : Color.clear)
            RoundedRectangle(cornerRadius: round ? 11 : 9, style: .continuous)
                .strokeBorder(on ? Pearl.green : Pearl.ink.opacity(0.22), lineWidth: 1.5)
            if on {
                Image(systemName: "checkmark").font(.system(size: round ? 11 : 13, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: round ? 22 : 24, height: round ? 22 : 24)
    }
}

struct PersonRow: View {
    let member: Member
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Text(member.initials)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(on ? .white : Pearl.ink.opacity(0.6))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(on ? Pearl.green : Pearl.ink.opacity(0.08)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.name).font(.system(size: 17.5, weight: .semibold)).foregroundStyle(Pearl.ink)
                    Text(member.role).font(.system(size: 14)).foregroundStyle(Pearl.muted())
                }
                Spacer()
                CheckBox(on: on, round: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glass(19, on: on)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

struct NoteCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Capsule().fill(Pearl.crimson).frame(width: 2)
            content
        }
        .padding(.leading, 16).padding(.trailing, 16).padding(.vertical, 16)
        .glass(20)
    }
}

struct Pill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .glass(99)
    }
}

// MARK: Screen scaffold

struct ScreenScaffold<Content: View, Bottom: View>: View {
    var topPadding: CGFloat = 84
    @ViewBuilder var content: Content
    @ViewBuilder var bottom: Bottom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, topPadding)
                .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) { bottom }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 8)
                .background(
                    LinearGradient(colors: [Color(red: 0.965, green: 0.96, blue: 0.97).opacity(0), Color(red: 0.965, green: 0.96, blue: 0.97).opacity(0.92)],
                                   startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35))
                        .ignoresSafeArea(edges: .bottom)
                        .allowsHitTesting(false)
                )
        }
    }
}

struct TextFieldGlass: View {
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 19
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: size))
            .foregroundStyle(Pearl.ink)
            .padding(19)
            .glass(20)
    }
}
