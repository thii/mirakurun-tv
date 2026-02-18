import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    let client: MirakurunClient

    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Mirakurun Server") {
                    TextField("Server URL", text: $settings.serverAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Text("Default: \(SettingsStore.defaultServerAddress)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Playback") {
                    Toggle("Show Subtitles", isOn: $settings.subtitlesEnabled)
                }

                Section("Actions") {
                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        if isTesting {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Testing...")
                            }
                        } else {
                            Text("Test Connection")
                        }
                    }

                    Button("Reset to Defaults", role: .destructive) {
                        settings.resetToDefaults()
                        statusMessage = "Settings reset to default values."
                    }
                }

                if let statusMessage {
                    Section("Status") {
                        Text(statusMessage)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func testConnection() async {
        guard let serverURL = settings.serverURL else {
            statusMessage = "Invalid server URL."
            return
        }

        isTesting = true
        defer { isTesting = false }

        do {
            let version = try await client.checkVersion(serverURL: serverURL)
            if let latest = version.latest {
                statusMessage = "Connected. Mirakurun current=\(version.current), latest=\(latest)."
            } else {
                statusMessage = "Connected. Mirakurun current=\(version.current)."
            }
        } catch {
            statusMessage = "Connection failed: \(error.localizedDescription)"
        }
    }
}
