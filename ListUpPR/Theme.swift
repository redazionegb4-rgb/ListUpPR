import SwiftUI

extension Color {
    static let appPurple = Color(red: 0.42, green: 0.24, blue: 0.96)
    static let appPink = Color(red: 0.96, green: 0.20, blue: 0.55)
    static let appCyan = Color(red: 0.08, green: 0.76, blue: 0.92)
    static let appIndigo = Color(red: 0.18, green: 0.16, blue: 0.42)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            LinearGradient(colors: [.appPurple.opacity(0.16), .clear, .appPink.opacity(0.09)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(Color.appCyan.opacity(0.10)).frame(width: 260).blur(radius: 70).offset(x: 180, y: 250)
        }
    }
}

struct PremiumCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.10)))
            .shadow(color: .black.opacity(0.09), radius: 20, y: 10)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(LinearGradient(colors: [.appPurple, .appPink], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .appPurple.opacity(0.26), radius: 14, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SmallMetricCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.title3.bold()).foregroundStyle(Color.appPurple)
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
    }
}
