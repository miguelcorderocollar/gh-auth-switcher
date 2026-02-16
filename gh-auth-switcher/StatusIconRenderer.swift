import SwiftUI

struct StatusIconRenderer: View {
    static let neutralColor = Color.gray.opacity(0.8)

    let color: Color
    let hasError: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Base icon: template mode + primary = white on dark menu bar, black on light
            Image(systemName: "person.crop.circle")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.primary)
                .font(.system(size: 16, weight: .medium))

            // Colored badge circle for active account (or error)
            Circle()
                .fill(hasError ? Color.red : color)
                .frame(width: 8, height: 8)
                .overlay {
                    if hasError {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 5, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .offset(x: 4, y: -2)
        }
        .frame(width: 22, height: 16)
        .accessibilityLabel(hasError ? "GitHub auth error" : "GitHub active account color")
    }
}
