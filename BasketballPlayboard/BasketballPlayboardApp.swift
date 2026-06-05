import SwiftUI

@main
struct BasketballPlayboardApp: App {
    @StateObject private var playStore = PlayStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(playStore)
        }
    }
}
