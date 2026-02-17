import SwiftUI

struct ProgramsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var viewModel: ProgramsViewModel

    init(client: MirakurunClient) {
        _viewModel = StateObject(wrappedValue: ProgramsViewModel(client: client))
    }

    var body: some View {
        NavigationSplitView {
            List(viewModel.services, selection: $viewModel.selectedServiceID) { service in
                HStack(spacing: 12) {
                    ServiceLogoView(
                        logoURL: logoURL(for: service),
                        width: 72,
                        height: 40
                    )
                    Text(service.name)
                        .lineLimit(1)
                }
                .tag(Optional(service.id))
            }
            .navigationTitle("Programs")
        } detail: {
            detailView
        }
        .task(id: settings.serverAddress) {
            await viewModel.reload(serverURL: settings.serverURL)
        }
        .onChange(of: viewModel.selectedServiceID) { _, _ in
            Task {
                await viewModel.loadProgramsForSelected(serverURL: settings.serverURL)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let service = viewModel.selectedService {
            List(viewModel.programs) { program in
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
            .navigationTitle(service.name)
            .overlay {
                if viewModel.isLoadingPrograms {
                    ProgressView("Loading Programs...")
                }
            }
        } else {
            ContentUnavailableView(
                "No Channel Selected",
                systemImage: "list.bullet",
                description: Text(viewModel.errorMessage ?? "Select a channel to browse programs.")
            )
        }
    }

    private func logoURL(for service: MirakurunService) -> URL? {
        guard service.hasLogoData == true, let serverURL = settings.serverURL else { return nil }
        return MirakurunEndpointBuilder(serverURL: serverURL).serviceLogoURL(serviceID: service.id)
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
}
