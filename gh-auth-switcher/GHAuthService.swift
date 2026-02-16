import Foundation

struct GHAccount: Identifiable, Hashable {
    let host: String
    let login: String
    let isActive: Bool

    var id: String {
        "\(host)|\(login)"
    }
}

enum GHAuthServiceError: Error {
    case ghNotInstalled
    case invalidStatusPayload
    case noAuthenticatedAccounts
    case commandFailed(command: String, details: String)
}

extension GHAuthServiceError {
    var userTitle: String {
        switch self {
        case .ghNotInstalled:
            return "GitHub CLI was not found"
        case .invalidStatusPayload:
            return "Could not read gh auth status"
        case .noAuthenticatedAccounts:
            return "No authenticated accounts found"
        case .commandFailed(let command, _):
            return "Command failed: \(command)"
        }
    }

    var userDetails: String {
        switch self {
        case .ghNotInstalled:
            return "Install GitHub CLI and make sure `gh` is available in PATH."
        case .invalidStatusPayload:
            return "The output from `gh auth status --json hosts` was not valid JSON."
        case .noAuthenticatedAccounts:
            return "Run `gh auth login` in Terminal, then click Refresh."
        case .commandFailed(_, let details):
            return details
        }
    }
}

final class GHAuthService {
    nonisolated func fetchAccounts() async throws -> [GHAccount] {
        let output = try await runGH(arguments: ["auth", "status", "--json", "hosts"])

        let rawHosts: [String: [[String: Any]]]
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: Data(output.stdout.utf8))
            guard
                let root = jsonObject as? [String: Any],
                let hosts = root["hosts"] as? [String: [[String: Any]]]
            else {
                throw GHAuthServiceError.invalidStatusPayload
            }
            rawHosts = hosts
        } catch {
            throw GHAuthServiceError.invalidStatusPayload
        }

        let accounts = rawHosts
            .reduce(into: [GHAccount]()) { partialResult, pair in
                let (host, entries) = pair
                for entry in entries {
                    guard let login = entry["login"] as? String else {
                        continue
                    }

                    let account = GHAccount(
                        host: (entry["host"] as? String) ?? host,
                        login: login,
                        isActive: (entry["active"] as? Bool) ?? false
                    )
                    partialResult.append(account)
                }
            }
            .sorted {
                if $0.isActive != $1.isActive {
                    return $0.isActive && !$1.isActive
                }
                if $0.host != $1.host {
                    return $0.host.localizedCaseInsensitiveCompare($1.host) == .orderedAscending
                }
                return $0.login.localizedCaseInsensitiveCompare($1.login) == .orderedAscending
            }

        guard !accounts.isEmpty else {
            throw GHAuthServiceError.noAuthenticatedAccounts
        }

        return accounts
    }

    nonisolated func switchAccount(host: String, login: String) async throws {
        _ = try await runGH(arguments: ["auth", "switch", "--hostname", host, "--user", login])
        _ = try await runGH(arguments: ["auth", "setup-git", "--hostname", host])
    }

    /// Applies git config --global user.name and user.email. Ignores errors (git may not be installed).
    nonisolated func applyGitProfile(name: String, email: String) async {
        let nameTrimmed = name.trimmingCharacters(in: .whitespaces)
        let emailTrimmed = email.trimmingCharacters(in: .whitespaces)
        guard !nameTrimmed.isEmpty || !emailTrimmed.isEmpty else { return }

        if !nameTrimmed.isEmpty {
            _ = try? await runCommand(executable: "/usr/bin/git", arguments: ["config", "--global", "user.name", nameTrimmed])
        }
        if !emailTrimmed.isEmpty {
            _ = try? await runCommand(executable: "/usr/bin/git", arguments: ["config", "--global", "user.email", emailTrimmed])
        }
    }

    nonisolated private func runCommand(executable: String, arguments: [String]) async throws -> CommandOutput {
        try await Task.detached(priority: .userInitiated) {
            try self.runCommandSync(executable: executable, arguments: arguments)
        }.value
    }

    nonisolated private func runCommandSync(executable: String, arguments: [String]) throws -> CommandOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try? process.run()
        process.waitUntilExit()

        let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return CommandOutput(stdout: stdout, stderr: stderr)
    }

    nonisolated private func runGH(arguments: [String]) async throws -> CommandOutput {
        try await Task.detached(priority: .userInitiated) {
            try self.runGHSync(arguments: arguments)
        }.value
    }

    nonisolated private func runGHSync(arguments: [String]) throws -> CommandOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh"] + arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = commandEnvironment()

        do {
            try process.run()
        } catch {
            throw GHAuthServiceError.ghNotInstalled
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus != 0 {
            let detail = stderr.isEmpty ? stdout : stderr
            let errorDetail = detail.isEmpty ? "Unknown gh CLI error." : detail

            if errorDetail.localizedCaseInsensitiveContains("No such file")
                || errorDetail.localizedCaseInsensitiveContains("command not found") {
                throw GHAuthServiceError.ghNotInstalled
            }

            throw GHAuthServiceError.commandFailed(
                command: "gh \(arguments.joined(separator: " "))",
                details: errorDetail
            )
        }

        return CommandOutput(stdout: stdout, stderr: stderr)
    }

    nonisolated private func commandEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let preferredPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        if let existingPath = environment["PATH"], !existingPath.isEmpty {
            environment["PATH"] = "\(existingPath):\(preferredPath)"
        } else {
            environment["PATH"] = preferredPath
        }

        return environment
    }
}

private struct CommandOutput {
    let stdout: String
    let stderr: String
}
