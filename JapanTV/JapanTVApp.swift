import SwiftUI

@main
struct JapanTVApp: App {
    @StateObject private var settings = SettingsStore()
    private let client = MirakurunClient()

    var body: some Scene {
        WindowGroup {
            ContentView(client: client)
                .environmentObject(settings)
        }
    }
}
