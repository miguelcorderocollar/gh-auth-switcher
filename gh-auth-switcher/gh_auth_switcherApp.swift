//
//  gh_auth_switcherApp.swift
//  gh-auth-switcher
//
//  Created by Miguel Cordero Collar on 16.02.26.
//

import SwiftUI

@main
struct gh_auth_switcherApp: App {
    @NSApplicationDelegateAdaptor(StatusItemAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
