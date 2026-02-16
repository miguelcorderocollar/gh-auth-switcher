//
//  SettingsView.swift
//  gh-auth-switcher
//

import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState

    var body: some View {
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

            Text("Account colors")
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
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(appState.color(for: account))
                                    .frame(width: 12, height: 12)

                                Text("\(account.login)@\(account.host)")
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer()

                                ColorPaletteSelector(
                                    selectedIndex: appState.colorIndex(for: account),
                                    palette: appState.palette
                                ) { newIndex in
                                    appState.assignColor(index: newIndex, to: account)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                        }
                    }
                }
                .frame(maxHeight: 280)
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
        .frame(width: 320)
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
