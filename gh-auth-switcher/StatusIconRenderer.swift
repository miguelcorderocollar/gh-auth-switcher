import AppKit
import SwiftUI

struct StatusIconRenderer {
    static let neutralColor = Color.gray.opacity(0.8)

    static func makeBaseImage() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let image = NSImage(
            systemSymbolName: "person.crop.circle",
            accessibilityDescription: "GitHub account switcher"
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    static func makeBadgeColor(color: Color, hasError: Bool) -> NSColor {
        NSColor(hasError ? .red : color)
    }
}
