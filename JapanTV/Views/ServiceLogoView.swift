import SwiftUI

struct ServiceLogoView: View {
    let logoURL: URL?
    let width: CGFloat
    let height: CGFloat

    init(logoURL: URL?, width: CGFloat = 120, height: CGFloat = 68) {
        self.logoURL = logoURL
        self.width = width
        self.height = height
    }

    var body: some View {
        Group {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.25))
            Image(systemName: "tv")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
