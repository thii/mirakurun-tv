import SwiftUI

struct ChannelRowView: View {
    let service: MirakurunService
    let logoURL: URL?
    let isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            logo

            Text(service.name)
                .font(.system(size: 34, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.62)
                .padding(.horizontal, 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 230, maxHeight: 230)
        .background(tileBackground)
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .shadow(
            color: .black.opacity(isFocused ? 0.54 : 0.28),
            radius: isFocused ? 30 : 12,
            x: 0,
            y: isFocused ? 16 : 8
        )
        .animation(.easeOut(duration: 0.18), value: isFocused)
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
                        .scaledToFit()
                        .frame(maxWidth: 144, maxHeight: 78)
                case .failure:
                    placeholderLogo
                @unknown default:
                    placeholderLogo
                }
            }
            .frame(maxWidth: 152, minHeight: 80, maxHeight: 80)
        } else {
            placeholderLogo
                .frame(maxWidth: 152, minHeight: 80, maxHeight: 80)
        }
    }

    private var placeholderLogo: some View {
        Image(systemName: "tv")
            .font(.system(size: 46, weight: .regular))
            .foregroundStyle(.white.opacity(0.62))
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.24, green: 0.25, blue: 0.28),
                        Color(red: 0.18, green: 0.19, blue: 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        isFocused ? .white.opacity(0.9) : .white.opacity(0.12),
                        lineWidth: isFocused ? 4 : 1
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .brightness(isFocused ? 0.02 : 0)
    }
}
