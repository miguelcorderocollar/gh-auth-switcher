//
//  gh_auth_switcherApp.swift
//  gh-auth-switcher
//
//  Created by Miguel Cordero Collar on 16.02.26.
//

import SwiftUI

@main
struct gh_auth_switcherApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(appState)
        } label: {
            StatusIconRenderer(
                color: appState.menuBarColor,
                hasError: appState.hasError
            )
        }
        .menuBarExtraStyle(.window)
    }
}
