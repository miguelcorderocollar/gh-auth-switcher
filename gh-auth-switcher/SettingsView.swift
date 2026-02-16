//
//  SettingsView.swift
//  gh-auth-switcher
//

import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState

    var body: some View {
        settingsContent
            .task { await appState.refreshDiscoveredGitProfiles() }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            Text("Accounts")
                .font(.subheadline)
                .fontWeight(.medium)

            if appState.accounts.isEmpty {
                Text("No accounts. Import from gh first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(appState.accounts) { account in
                            AccountSettingsRow(account: account)
                        }
                    }
                }
                .frame(maxHeight: 400)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Add profile")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Profiles come from ~/.gitconfig and [include] files. Add custom ones:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AddProfileRow()
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard shortcuts")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("⌘, Settings  ·  ⌘Q Quit")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(width: 380)
    }
}

private struct AddProfileRow: View {
    @EnvironmentObject private var appState: AppState
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
            Button {
                let profile = GitProfile(name: name.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces))
                guard !profile.isEmpty else { return }
                appState.addManualProfile(profile)
                name = ""
                email = ""
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty && email.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

private struct AccountSettingsRow: View {
    @EnvironmentObject private var appState: AppState
    let account: GHAccount

    private var accountColor: Color {
        appState.color(for: account)
    }

    private var profilesForPicker: [GitProfile] {
        let stored = appState.gitProfile(for: account)
        var list = appState.discoveredGitProfiles
        if !stored.isEmpty && !list.contains(stored) {
            list.append(stored)
            list.sort { $0.displayString.localizedCaseInsensitiveCompare($1.displayString) == .orderedAscending }
        }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accountColor)
                    .frame(width: 14, height: 14)
                Text("\(account.login)@\(account.host)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            TextField("Label (e.g. Work, Personal)", text: accountLabelBinding)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)

            HStack(spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ColorPaletteSelector(
                    selectedIndex: appState.colorIndex(for: account),
                    palette: appState.palette
                ) { newIndex in
                    appState.assignColor(index: newIndex, to: account)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Git profile (used when switching)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: gitProfileBinding) {
                    Text("None").tag(GitProfile(name: "", email: ""))
                    ForEach(profilesForPicker, id: \.self) { profile in
                        Text(profile.displayString).tag(profile)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(accountColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accountColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var gitProfileBinding: Binding<GitProfile> {
        Binding(
            get: { appState.gitProfile(for: account) },
            set: { appState.setGitProfile($0, for: account) }
        )
    }

    private var accountLabelBinding: Binding<String> {
        Binding(
            get: { appState.accountLabel(for: account) ?? "" },
            set: { appState.setAccountLabel($0.isEmpty ? nil : $0, for: account) }
        )
    }
}

private struct ColorPaletteSelector: View {
    let selectedIndex: Int
    let palette: [Color]
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(palette.enumerated()), id: \.offset) { index, color in
                Button {
                    onSelect(index)
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .stroke(
                                    selectedIndex == index ? Color.primary : Color.clear,
                                    lineWidth: 1.5
                                )
                        }
                }
                .buttonStyle(.plain)
                .help("Set color \(index + 1)")
            }
        }
    }
}
