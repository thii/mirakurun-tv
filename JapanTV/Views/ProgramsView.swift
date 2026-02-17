import SwiftUI

struct ProgramsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var viewModel: ProgramsViewModel
    @State private var selectedService: MirakurunService?
    @State private var didAutoOpenDetailForUITest = false

    private let autoOpenProgramDetailForUITest: Bool

    init(client: MirakurunClient) {
        _viewModel = StateObject(wrappedValue: ProgramsViewModel(client: client))
        self.autoOpenProgramDetailForUITest = ProcessInfo.processInfo.arguments.contains("-uitest-auto-open-program-detail")
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.services.isEmpty && !viewModel.isLoadingServices {
                    ContentUnavailableView(
                        "No Channels",
                        systemImage: "list.bullet.rectangle",
                        description: Text(viewModel.errorMessage ?? "Check your server settings and connection.")
                    )
                } else {
                    List(viewModel.services) { service in
                        Button {
                            selectedService = service
                        } label: {
                            HStack(spacing: 12) {
                                ServiceLogoView(
                                    logoURL: logoURL(for: service),
                                    width: 72,
                                    height: 40
                                )
                                Text(service.name)
                                    .lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("programs.channelRow.\(service.id)")
                    }
                    .accessibilityIdentifier("programs.channelList")
                }
            }
            .navigationTitle("Programs")
            .overlay {
                if viewModel.isLoadingServices {
                    ProgressView("Loading Channels...")
                }
            }
        }
        .task(id: settings.serverAddress) {
            await viewModel.reload(serverURL: settings.serverURL)
        }
        .onChange(of: viewModel.services) { _, services in
            if services.isEmpty {
                selectedService = nil
                return
            }

            if let selectedService, !services.contains(where: { $0.id == selectedService.id }) {
                self.selectedService = nil
            }

            if autoOpenProgramDetailForUITest, !didAutoOpenDetailForUITest, let firstService = services.first {
                selectedService = firstService
                didAutoOpenDetailForUITest = true
            }
        }
        .fullScreenCover(item: $selectedService) { service in
            ServiceProgramsView(
                service: service,
                viewModel: viewModel,
                onMenuBack: {
                    selectedService = nil
                }
            )
        }
    }

    private func logoURL(for service: MirakurunService) -> URL? {
        guard service.hasLogoData == true, let serverURL = settings.serverURL else { return nil }
        return MirakurunEndpointBuilder(serverURL: serverURL).serviceLogoURL(serviceID: service.id)
    }

    private struct ServiceProgramsView: View {
        @EnvironmentObject private var settings: SettingsStore

        let service: MirakurunService
        let viewModel: ProgramsViewModel
        let onMenuBack: () -> Void

        @State private var programs: [MirakurunProgram] = []
        @State private var programNavigationPath: [MirakurunProgram] = []
        @State private var isLoading = false
        @State private var errorMessage: String?

        var body: some View {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.08)
                    .ignoresSafeArea()

                NavigationStack(path: $programNavigationPath) {
                    List(programs) { program in
                        NavigationLink(value: program) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(program.name ?? "(No title)")
                                    .font(.headline)
                                    .lineLimit(2)

                                Text(formatRange(program))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let description = program.description, !description.isEmpty {
                                    Text(description)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color(red: 0.10, green: 0.11, blue: 0.15))
                    }
                    .listStyle(.plain)
                    .background(Color(red: 0.05, green: 0.06, blue: 0.08))
                    .accessibilityIdentifier("programs.detailList")
                    .navigationTitle(service.name)
                    .navigationDestination(for: MirakurunProgram.self) { program in
                        ProgramDetailView(program: program)
                    }
                    .overlay {
                        if isLoading {
                            ProgressView("Loading Programs...")
                        } else if programs.isEmpty {
                            ContentUnavailableView(
                                "No Programs",
                                systemImage: "list.bullet.rectangle",
                                description: Text(errorMessage ?? "No program data available for this channel.")
                            )
                        }
                    }
                }
            }
            .task(id: settings.serverAddress) {
                await loadPrograms()
            }
            .onExitCommand {
                if !programNavigationPath.isEmpty {
                    programNavigationPath.removeLast()
                } else {
                    onMenuBack()
                }
            }
        }

        private func loadPrograms() async {
            isLoading = true
            defer { isLoading = false }

            do {
                programs = try await viewModel.fetchPrograms(for: service, serverURL: settings.serverURL)
                errorMessage = nil
            } catch {
                programs = []
                errorMessage = error.localizedDescription
            }
        }

        private func formatRange(_ program: MirakurunProgram) -> String {
            "\(Self.timeFormatter.string(from: program.startDate)) - \(Self.timeFormatter.string(from: program.endDate))"
        }

        private static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter
        }()

        private struct ProgramDetailView: View {
            let program: MirakurunProgram

            var body: some View {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(program.name ?? "(No title)")
                            .font(.title2)
                            .bold()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Time")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("\(Self.dateTimeFormatter.string(from: program.startDate)) - \(Self.dateTimeFormatter.string(from: program.endDate))")
                                .font(.body)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(program.description ?? "No description available.")
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 64)
                    .padding(.vertical, 48)
                }
                .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
                .navigationTitle("Program Details")
                .accessibilityIdentifier("programs.programDetail")
            }

            private static let dateTimeFormatter: DateFormatter = {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter
            }()
        }
    }
}
