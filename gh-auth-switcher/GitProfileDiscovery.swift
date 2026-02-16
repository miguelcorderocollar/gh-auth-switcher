//
//  GitProfileDiscovery.swift
//  gh-auth-switcher
//

import Foundation

/// Discovers git user profiles from the machine's config:
/// - Global config (~/.gitconfig, ~/.config/git/config)
/// - Included files ([include] and [includeIf] paths)
final class GitProfileDiscovery {
    nonisolated func discoverProfiles() async -> [GitProfile] {
        await Task.detached(priority: .userInitiated, operation: Self.discoverProfilesSync).value
    }

    nonisolated private static func discoverProfilesSync() -> [GitProfile] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var seen = Set<String>()
        var result: [GitProfile] = []

        let configPaths = [
            "\(home)/.gitconfig",
            "\(home)/.config/git/config"
        ]

        var filesToRead: [String] = []
        for path in configPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            filesToRead.append(path)
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let includePaths = Self.parseIncludePaths(from: content, home: home)
                for inc in includePaths where FileManager.default.fileExists(atPath: inc) {
                    filesToRead.append(inc)
                }
            }
        }

        for path in filesToRead {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let profiles = Self.parseUserSections(from: content)
            for p in profiles {
                let key = "\(p.name)|\(p.email)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                result.append(p)
            }
        }

        return result.sorted {
            Self.sortKey(for: $0).localizedCaseInsensitiveCompare(Self.sortKey(for: $1)) == .orderedAscending
        }
    }

    nonisolated private static func parseIncludePaths(from content: String, home: String) -> [String] {
        var paths: [String] = []
        var inIncludeSection = false
        for line in content.split(separator: "\n") {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                inIncludeSection = trimmed.lowercased().contains("include")
            } else if inIncludeSection, trimmed.lowercased().hasPrefix("path"), trimmed.contains("=") {
                let value = trimmed.split(separator: "=", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                let expanded = value.replacingOccurrences(of: "~", with: home)
                if !expanded.isEmpty {
                    paths.append(expanded)
                }
            }
        }
        return paths
    }

    nonisolated private static func parseUserSections(from content: String) -> [GitProfile] {
        var result: [GitProfile] = []
        var inUser = false
        var name = ""
        var email = ""

        for line in content.split(separator: "\n") {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                if inUser && (!name.isEmpty || !email.isEmpty) {
                    result.append(GitProfile(name: name, email: email))
                }
                inUser = trimmed.lowercased().hasPrefix("[user]")
                name = ""
                email = ""
                continue
            }
            guard inUser else { continue }
            if trimmed.lowercased().hasPrefix("name") && trimmed.contains("=") {
                name = trimmed.split(separator: "=", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            } else if trimmed.lowercased().hasPrefix("email") && trimmed.contains("=") {
                email = trimmed.split(separator: "=", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            }
        }
        if inUser && (!name.isEmpty || !email.isEmpty) {
            result.append(GitProfile(name: name, email: email))
        }
        return result
    }

    nonisolated private static func sortKey(for profile: GitProfile) -> String {
        let name = profile.name.trimmingCharacters(in: .whitespaces)
        let email = profile.email.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty && !email.isEmpty {
            return "\(name) <\(email)>"
        }
        if !email.isEmpty { return email }
        if !name.isEmpty { return name }
        return "—"
    }
}
