import SwiftUI

@main
struct FileExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                HubView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
