import SwiftUI

extension Color {
    static let appPurple = Color(red: 0.53, green: 0.30, blue: 1.00)
    static let appPink = Color(red: 1.00, green: 0.20, blue: 0.57)
    static let appCyan = Color(red: 0.00, green: 0.82, blue: 0.96)
    static let appIndigo = Color(red: 0.08, green: 0.06, blue: 0.18)
    static let appNavy = Color(red: 0.035, green: 0.035, blue: 0.075)
    static let appCard = Color.white.opacity(0.075)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color.appNavy.ignoresSafeArea()
            LinearGradient(
                colors: [.appPurple.opacity(0.24), .clear, .appPink.opacity(0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            Circle().fill(Color.appCyan.opacity(0.13)).frame(width: 300).blur(radius: 85).offset(x: 190, y: 280)
            Circle().fill(Color.appPink.opacity(0.11)).frame(width: 250).blur(radius: 80).offset(x: -170, y: -260)
        }
    }
}

struct PremiumCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(18)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.11), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(LinearGradient(colors: [.appPurple, .appPink], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .appPurple.opacity(0.30), radius: 16, y: 9)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SmallMetricCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.title3.bold()).foregroundStyle(Color.appCyan)
                Text(value).font(.system(size: 30, weight: .black, design: .rounded))
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GradientIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName).font(.headline.bold()).foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(LinearGradient(colors: [.appPurple, .appPink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: .appPurple.opacity(0.25), radius: 10, y: 5)
    }
}
