import SwiftUI
import Observation

enum MRMainTab: Hashable {
    case boards
    case library
    case atlas
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: MRMainTab = .boards
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView { hasCompletedOnboarding = true }
            }
        }
        .tint(MRColor.accent)
        .background(MRColor.background.ignoresSafeArea())
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack { BoardsHomeView() }
                .tag(MRMainTab.boards)
                .tabItem { Label("보드", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }

            NavigationStack { BoardLibraryView() }
                .tag(MRMainTab.library)
                .tabItem { Label("보관함", systemImage: "rectangle.stack") }

            NavigationStack { AtlasView() }
                .tag(MRMainTab.atlas)
                .tabItem { Label("아틀라스", systemImage: "map") }
        }
        .toolbarBackground(.regularMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
