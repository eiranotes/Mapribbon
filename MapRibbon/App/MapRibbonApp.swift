import SwiftUI
import SwiftData

@main
struct MapRibbonApp: App {
    @State private var photoLibrary = PhotoLibraryService()
    @State private var store = StoreService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(photoLibrary)
                .environment(store)
                .tint(MRColor.accent)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: SavedBoard.self)
    }
}
