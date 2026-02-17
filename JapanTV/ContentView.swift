import SwiftUI

struct ContentView: View {
    private enum RootTab: Hashable {
        case channels
        case programs
        case settings
    }

    let client: MirakurunClient
    @State private var selectedTab: RootTab

    init(client: MirakurunClient) {
        self.client = client

        if ProcessInfo.processInfo.arguments.contains("-uitest-open-programs-tab") {
            _selectedTab = State(initialValue: .programs)
        } else {
            _selectedTab = State(initialValue: .channels)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChannelsView(client: client)
                .tabItem {
                    Label("Channels", systemImage: "tv")
                }
                .tag(RootTab.channels)

            ProgramsView(client: client)
                .tabItem {
                    Label("Programs", systemImage: "list.bullet.rectangle")
                }
                .tag(RootTab.programs)

            SettingsView(client: client)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(RootTab.settings)
        }
    }
}
