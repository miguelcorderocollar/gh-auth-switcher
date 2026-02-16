import SwiftUI

struct GitProfile: Equatable, Hashable {
    var name: String
    var email: String

    nonisolated var isEmpty: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty && email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    nonisolated var displayString: String {
        let n = name.trimmingCharacters(in: .whitespaces)
        let e = email.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty && !e.isEmpty {
            return "\(n) <\(e)>"
        }
        if !e.isEmpty { return e }
        if !n.isEmpty { return n }
        return "—"
    }
}

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
    private let gitProfileMapKey = "ghAuthSwitcher.gitProfileMap"
    private let manualProfilesKey = "ghAuthSwitcher.manualGitProfiles"
    private let accountLabelsKey = "ghAuthSwitcher.accountLabels"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func manualGitProfiles() -> [GitProfile] {
        guard let data = defaults.data(forKey: manualProfilesKey),
              let decoded = try? JSONDecoder().decode([StoredGitProfile].self, from: data)
        else { return [] }
        return decoded.map { GitProfile(name: $0.name, email: $0.email) }
    }

    func addManualProfile(_ profile: GitProfile) {
        guard !profile.isEmpty else { return }
        var list = manualGitProfiles()
        guard !list.contains(profile) else { return }
        list.append(profile)
        list.sort { $0.displayString.localizedCaseInsensitiveCompare($1.displayString) == .orderedAscending }
        if let data = try? JSONEncoder().encode(list.map { StoredGitProfile(name: $0.name, email: $0.email) }) {
            defaults.set(data, forKey: manualProfilesKey)
        }
    }

    func removeManualProfile(_ profile: GitProfile) {
        let list = manualGitProfiles().filter { $0 != profile }
        if let data = try? JSONEncoder().encode(list.map { StoredGitProfile(name: $0.name, email: $0.email) }) {
            defaults.set(data, forKey: manualProfilesKey)
        }
    }

    func accountLabel(for accountID: String) -> String? {
        return loadAccountLabels()[accountID]
    }

    func setAccountLabel(_ label: String?, for accountID: String) {
        var map = loadAccountLabels()
        if let label = label?.trimmingCharacters(in: .whitespaces), !label.isEmpty {
            map[accountID] = label
        } else {
            map.removeValue(forKey: accountID)
        }
        saveAccountLabels(map)
    }

    private func loadAccountLabels() -> [String: String] {
        guard let map = defaults.dictionary(forKey: accountLabelsKey) as? [String: String] else {
            return [:]
        }
        return map
    }

    private func saveAccountLabels(_ map: [String: String]) {
        defaults.set(map, forKey: accountLabelsKey)
    }

    func gitProfile(for accountID: String) -> GitProfile {
        loadGitProfileMap()[accountID] ?? GitProfile(name: "", email: "")
    }

    func setGitProfile(_ profile: GitProfile, for accountID: String) {
        var map = loadGitProfileMap()
        if profile.isEmpty {
            map.removeValue(forKey: accountID)
        } else {
            map[accountID] = profile
        }
        saveGitProfileMap(map)
    }

    private func loadGitProfileMap() -> [String: GitProfile] {
        guard let data = defaults.data(forKey: gitProfileMapKey),
              let decoded = try? JSONDecoder().decode([String: StoredGitProfile].self, from: data)
        else { return [:] }
        return decoded.mapValues { GitProfile(name: $0.name, email: $0.email) }
    }

    private func saveGitProfileMap(_ map: [String: GitProfile]) {
        let encoded = map.mapValues { StoredGitProfile(name: $0.name, email: $0.email) }
        if let data = try? JSONEncoder().encode(encoded) {
            defaults.set(data, forKey: gitProfileMapKey)
        }
    }

    private struct StoredGitProfile: Codable {
        let name: String
        let email: String
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
