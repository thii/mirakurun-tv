import SwiftUI

struct ContentView: View {
    let client: MirakurunClient

    var body: some View {
        TabView {
            ChannelsView(client: client)
                .tabItem {
                    Label("Channels", systemImage: "tv")
                }

            ProgramsView(client: client)
                .tabItem {
                    Label("Programs", systemImage: "list.bullet.rectangle")
                }

            SettingsView(client: client)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
