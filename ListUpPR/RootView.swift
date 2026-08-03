import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color.indigo.opacity(0.45), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            switch model.selectedRole {
            case .pr: PRDashboardView()
            case .entrance: EntranceDashboardView()
            case nil: WelcomeView()
            }
        }
    }
}
