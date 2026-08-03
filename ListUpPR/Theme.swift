import SwiftUI

extension Color {
    static let appPurple = Color(red: 0.48, green: 0.22, blue: 0.98)
    static let appPink = Color(red: 0.98, green: 0.20, blue: 0.56)
    static let appCyan = Color(red: 0.15, green: 0.82, blue: 0.94)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Circle().fill(Color.appPurple.opacity(0.20)).frame(width: 330).blur(radius: 80).offset(x: 170, y: -320)
            Circle().fill(Color.appPink.opacity(0.13)).frame(width: 280).blur(radius: 90).offset(x: -190, y: 330)
        }
    }
}

struct PremiumCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(LinearGradient(colors: [.appPurple, .appPink], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SmallMetricCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.appPurple)
                Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
                Text(title).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
