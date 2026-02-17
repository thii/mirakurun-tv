import SwiftUI

struct ChannelRowView: View {
    let service: MirakurunService
    let logoURL: URL?

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            logo
            Text(service.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 12)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var logo: some View {
        if let logoURL {
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .empty:
                    placeholderLogo
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 130, height: 80)
                case .failure:
                    placeholderLogo
                @unknown default:
                    placeholderLogo
                }
            }
            .frame(width: 130, height: 80)
        } else {
            placeholderLogo
                .frame(width: 130, height: 80)
        }
    }

    private var placeholderLogo: some View {
        Image(systemName: "tv.fill")
            .font(.system(size: 48))
            .foregroundStyle(.secondary)
    }
}
