import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    struct ErrorBanner: Identifiable {
        let id = UUID()
        let title: String
        let details: String?
    }

    @Published private(set) var accounts: [GHAccount] = []
    @Published private(set) var discoveredGitProfiles: [GitProfile] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var switchingAccountID: String?
    @Published private(set) var hasLoaded = false
    @Published var errorBanner: ErrorBanner?

    private let service: GHAuthService
    private let store: AccountStore
    private let gitDiscovery = GitProfileDiscovery()
    private var lastAction: RetryAction = .refresh

    enum RetryAction {
        case refresh
        case switchAccount(host: String, login: String)
    }

    init(service: GHAuthService, store: AccountStore) {
        self.service = service
        self.store = store
    }

    convenience init() {
        self.init(service: GHAuthService(), store: AccountStore())
    }

    var isWorking: Bool {
        isRefreshing || switchingAccountID != nil
    }

    var palette: [Color] {
        AccountStore.palette
    }

    var activeAccount: GHAccount? {
        accounts.first(where: { $0.isActive })
    }

    var hasError: Bool {
        errorBanner != nil
    }

    var menuBarColor: Color {
        if hasError {
            return .red
        }
        guard let activeAccount else {
            return StatusIconRenderer.neutralColor
        }
        return color(for: activeAccount)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }
        hasLoaded = true
        await refreshAccounts()
    }

    func refreshAccounts() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        lastAction = .refresh
        errorBanner = nil

        do {
            accounts = try await service.fetchAccounts()
        } catch {
            accounts = []
            errorBanner = mapError(error)
        }

        isRefreshing = false
    }

    func switchAccount(to account: GHAccount) async {
        guard switchingAccountID == nil else {
            return
        }
        guard !account.isActive else {
            return
        }

        switchingAccountID = account.id
        lastAction = .switchAccount(host: account.host, login: account.login)
        errorBanner = nil

        do {
            try await service.switchAccount(host: account.host, login: account.login)
            let profile = store.gitProfile(for: account.id)
            if !profile.isEmpty {
                await service.applyGitProfile(name: profile.name, email: profile.email)
            }
            accounts = try await service.fetchAccounts()
        } catch {
            errorBanner = mapError(error)
        }

        switchingAccountID = nil
    }

    func retryLastAction() async {
        switch lastAction {
        case .refresh:
            await refreshAccounts()
        case .switchAccount(let host, let login):
            let account = GHAccount(host: host, login: login, isActive: false)
            await switchAccount(to: account)
        }
    }

    func colorIndex(for account: GHAccount) -> Int {
        store.colorIndex(for: account.id)
    }

    func color(for account: GHAccount) -> Color {
        let index = colorIndex(for: account)
        return palette[index]
    }

    func assignColor(index: Int, to account: GHAccount) {
        store.setColorIndex(index, for: account.id)
        objectWillChange.send()
    }

    func gitProfile(for account: GHAccount) -> GitProfile {
        store.gitProfile(for: account.id)
    }

    func setGitProfile(_ profile: GitProfile, for account: GHAccount) {
        store.setGitProfile(profile, for: account.id)
        objectWillChange.send()
    }

    func refreshDiscoveredGitProfiles() async {
        let fromConfig = await gitDiscovery.discoverProfiles()
        let manual = store.manualGitProfiles()
        var combined = fromConfig
        for p in manual where !combined.contains(p) {
            combined.append(p)
        }
        combined.sort { $0.displayString.localizedCaseInsensitiveCompare($1.displayString) == .orderedAscending }
        discoveredGitProfiles = combined
    }

    func addManualProfile(_ profile: GitProfile) {
        store.addManualProfile(profile)
        Task { await refreshDiscoveredGitProfiles() }
    }

    func removeManualProfile(_ profile: GitProfile) {
        store.removeManualProfile(profile)
        objectWillChange.send()
        Task { await refreshDiscoveredGitProfiles() }
    }

    var manualProfiles: [GitProfile] {
        store.manualGitProfiles()
    }

    func accountLabel(for account: GHAccount) -> String? {
        store.accountLabel(for: account.id)
    }

    func setAccountLabel(_ label: String?, for account: GHAccount) {
        store.setAccountLabel(label, for: account.id)
        objectWillChange.send()
    }

    func displayName(for account: GHAccount) -> String {
        if let label = store.accountLabel(for: account.id), !label.isEmpty {
            return label
        }
        return "\(account.login)@\(account.host)"
    }

    private func mapError(_ error: Error) -> ErrorBanner {
        if let serviceError = error as? GHAuthServiceError {
            return ErrorBanner(
                title: serviceError.userTitle,
                details: serviceError.userDetails
            )
        }

        return ErrorBanner(
            title: "Unexpected error",
            details: error.localizedDescription
        )
    }
}

extension AppState {
    static var preview: AppState {
        let state = AppState()
        state.accounts = [
            GHAccount(host: "github.com", login: "octocat", isActive: true),
            GHAccount(host: "github.com", login: "teammate", isActive: false)
        ]
        return state
    }
}
