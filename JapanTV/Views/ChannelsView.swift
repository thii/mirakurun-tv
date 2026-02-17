import SwiftUI

struct ChannelsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var viewModel: ChannelsViewModel
    @State private var selectedService: MirakurunService?
    @FocusState private var focusedServiceID: Int?

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 30)]

    init(client: MirakurunClient) {
        _viewModel = StateObject(wrappedValue: ChannelsViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                    .ignoresSafeArea()

                Group {
                    if viewModel.services.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView(
                            "No Channels",
                            systemImage: "tv.slash",
                            description: Text(viewModel.errorMessage ?? "Check your server settings and connection.")
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(viewModel.services) { service in
                                    Button {
                                        selectedService = service
                                    } label: {
                                        ChannelRowView(
                                            service: service,
                                            logoURL: viewModel.logoURL(for: service, serverURL: settings.serverURL)
                                        )
                                    }
                                    .buttonStyle(.card)
                                    .focused($focusedServiceID, equals: service.id)
                                    .accessibilityIdentifier("channels.channelButton.\(service.id)")
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.top, 48)
                            .padding(.bottom, 80)
                        }
                        .scrollIndicators(.hidden)
                        .accessibilityIdentifier("channels.grid")
                    }
                }
                .overlay(alignment: .bottom) {
                    if let errorMessage = viewModel.errorMessage, !viewModel.isLoading {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(12)
                    }
                }
            }
        }
        .task(id: settings.serverAddress) {
            await viewModel.reload(serverURL: settings.serverURL)
        }
        .onChange(of: viewModel.services) { _, services in
            guard !services.isEmpty else {
                focusedServiceID = nil
                return
            }
            guard let focusedServiceID else {
                self.focusedServiceID = services.first?.id
                return
            }
            let exists = services.contains { $0.id == focusedServiceID }
            if !exists {
                self.focusedServiceID = services.first?.id
            }
        }
        .fullScreenCover(item: $selectedService) { service in
            PlayerView(
                services: viewModel.services,
                initialServiceID: service.id
            )
                .environmentObject(settings)
        }
    }

    private var backgroundView: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.08)

            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.19, blue: 0.24).opacity(0.4),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [.white.opacity(0.08), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 900
            )
        }
    }
}
