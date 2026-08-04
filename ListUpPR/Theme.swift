import SwiftUI

extension Color {
    static let appPurple = Color(red: 0.00, green: 0.52, blue: 0.92)
    static let appPink = Color(red: 0.00, green: 0.76, blue: 0.68)
    static let appCyan = Color(red: 0.00, green: 0.68, blue: 0.90)
    static let appIndigo = Color(red: 0.02, green: 0.10, blue: 0.16)
    static let appNavy = Color(red: 0.025, green: 0.035, blue: 0.045)
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark {
                    Color.appNavy
                    LinearGradient(
                        colors: [.appPurple.opacity(0.20), .clear, .appPink.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle().fill(Color.appCyan.opacity(0.11)).frame(width: 300).blur(radius: 85).offset(x: 190, y: 280)
                    Circle().fill(Color.appPink.opacity(0.08)).frame(width: 250).blur(radius: 80).offset(x: -170, y: -260)
                } else {
                    Color(red: 0.955, green: 0.97, blue: 0.985)
                    LinearGradient(
                        colors: [Color.appCyan.opacity(0.13), .white.opacity(0.70), Color.appPink.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle().fill(Color.appCyan.opacity(0.10)).frame(width: 290).blur(radius: 80).offset(x: 190, y: 270)
                    Circle().fill(Color.appPink.opacity(0.07)).frame(width: 240).blur(radius: 75).offset(x: -160, y: -250)
                }
            }
            .ignoresSafeArea()
        }
    }
}

struct PremiumCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                colorScheme == .dark ? Color.white.opacity(0.075) : Color.white.opacity(0.88),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.11) : Color.black.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 22, y: 12)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [.appPurple, .appPink], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: .appPurple.opacity(0.24), radius: 16, y: 9)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SmallMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.title3.bold()).foregroundStyle(Color.appCyan)
                Text(value).font(.system(size: 30, weight: .black, design: .rounded))
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GradientIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(
                LinearGradient(colors: [.appPurple, .appPink], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .shadow(color: .appPurple.opacity(0.22), radius: 10, y: 5)
    }
}


struct FixedModalHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            if !title.isEmpty {
                Text(title).font(.headline)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chiudi")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }
}
