import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .environmentObject(appState)
                    .focusable()
                    .focusEffectDisabled()
                    .onKeyPress(.escape, phases: .down) { _ in
                        showSettings = false
                        return .handled
                    }
            } else {
                mainContent
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSettings)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection

            if let errorBanner = appState.errorBanner {
                errorSection(errorBanner)
            }

            Divider()

            if appState.isRefreshing && appState.accounts.isEmpty {
                loadingSection
            } else if appState.accounts.isEmpty {
                emptySection
            } else {
                accountListSection
            }

            Divider()
            footerSection
        }
        .padding(12)
        .frame(width: 280)
        .task {
            await appState.loadIfNeeded()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GH Auth Switcher")
                .font(.headline)

            if let activeAccount = appState.activeAccount {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.color(for: activeAccount))
                        .frame(width: 10, height: 10)
                    Text("\(activeAccount.login)@\(activeAccount.host)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                Text("No active account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func errorSection(_ errorBanner: AppState.ErrorBanner) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 3) {
                Text(errorBanner.title)
                    .font(.footnote)
                    .fontWeight(.semibold)

                if let details = errorBanner.details, !details.isEmpty {
                    Text(details)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 6)

            Button("Retry") {
                Task {
                    await appState.retryLastAction()
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(appState.isWorking)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.12))
        )
    }

    private var loadingSection: some View {
        HStack {
            Spacer()
            ProgressView("Loading accounts...")
                .controlSize(.small)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No authenticated GitHub accounts found in gh CLI.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Import from gh") {
                Task {
                    await appState.refreshAccounts()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(appState.isWorking)
        }
        .padding(.vertical, 2)
    }

    private var accountListSection: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(appState.accounts) { account in
                    AccountRowView(account: account)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 360)
    }

    private var footerSection: some View {
        HStack {
            Button(appState.isRefreshing ? "Refreshing..." : "Refresh") {
                Task {
                    await appState.refreshAccounts()
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(appState.isWorking)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: [.command])
            .help("Settings (⌘,)")

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}

private struct AccountRowView: View {
    @EnvironmentObject private var appState: AppState

    let account: GHAccount

    private var isActive: Bool {
        account.isActive
    }

    private var isSwitching: Bool {
        appState.switchingAccountID == account.id
    }

    var body: some View {
        Button {
            guard !isActive else { return }
            Task {
                await appState.switchAccount(to: account)
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(appState.color(for: account))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.login)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(account.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(appState.color(for: account))
                        .help("Active account")
                }

                if isSwitching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isActive || appState.isWorking)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.preview)
}
