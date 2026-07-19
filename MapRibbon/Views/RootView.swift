import SwiftUI

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
        .background(MRColor.background.ignoresSafeArea())
    }
}

enum MRMainTab: Hashable {
    case boards
    case library
    case atlas
}

struct MainTabView: View {
    @State private var selection: MRMainTab = .boards

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { BoardsHomeView() }
                .tag(MRMainTab.boards)
                .tabItem { Label("보드", systemImage: "rectangle.stack") }

            NavigationStack { BoardLibraryView() }
                .tag(MRMainTab.library)
                .tabItem { Label("보관함", systemImage: "books.vertical") }

            NavigationStack { AtlasView() }
                .tag(MRMainTab.atlas)
                .tabItem { Label("아틀라스", systemImage: "map") }
        }
    }
}
