import SwiftUI

final class AccountStore {
    static let palette: [Color] = [
        .red,
        .orange,
        .yellow,
        .green,
        .mint,
        .teal,
        .blue,
        .indigo,
        .purple,
        .pink
    ]

    private let defaults: UserDefaults
    private let colorMapKey = "ghAuthSwitcher.accountColorMap"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func colorIndex(for accountID: String) -> Int {
        let map = loadColorMap()
        if let index = map[accountID], Self.palette.indices.contains(index) {
            return index
        }
        return defaultColorIndex(for: accountID)
    }

    func setColorIndex(_ index: Int, for accountID: String) {
        guard Self.palette.indices.contains(index) else {
            return
        }

        var map = loadColorMap()
        map[accountID] = index
        saveColorMap(map)
    }

    private func loadColorMap() -> [String: Int] {
        guard let map = defaults.dictionary(forKey: colorMapKey) else {
            return [:]
        }
        return map.reduce(into: [String: Int]()) { partialResult, pair in
            guard let index = pair.value as? Int else {
                return
            }
            partialResult[pair.key] = index
        }
    }

    private func saveColorMap(_ map: [String: Int]) {
        defaults.set(map, forKey: colorMapKey)
    }

    private func defaultColorIndex(for accountID: String) -> Int {
        let paletteCount = max(1, Self.palette.count)
        let scalarSum = accountID.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult + Int(scalar.value)) % paletteCount
        }
        return scalarSum
    }
}
