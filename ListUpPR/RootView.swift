import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ZStack {
            AppBackground()
            switch model.selectedRole {
            case .pr: PRMainView()
            case .entrance: EntranceDashboardView()
            case nil: WelcomeView()
            }
        }
        .preferredColorScheme(model.theme.colorScheme)
    }
}
