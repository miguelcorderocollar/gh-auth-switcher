# Agent Instructions: gh-auth-switcher

Guidance for AI coding agents working on this macOS SwiftUI project.

## Project Context

- **Type**: macOS menu bar app (SwiftUI)
- **Primary goal**: Switch active GitHub CLI auth account and show a color badge for the active account
- **Xcode project**: `gh-auth-switcher.xcodeproj`
- **Scheme**: `gh-auth-switcher`
- **Source folder**: `gh-auth-switcher/` (uses `PBXFileSystemSynchronizedRootGroup`; new Swift files are auto-included)

## Build and Run

Run from the project root (folder containing `gh-auth-switcher.xcodeproj`):

```bash
xcodebuild -project "gh-auth-switcher.xcodeproj" -scheme "gh-auth-switcher" -configuration Debug -destination 'platform=macOS' build
```

If Xcode has a build database lock, use a custom DerivedData path:

```bash
xcodebuild -project "gh-auth-switcher.xcodeproj" -scheme "gh-auth-switcher" -configuration Debug -destination 'platform=macOS' -derivedDataPath ".build/DerivedData" build
```

## Coding Conventions

- Keep implementation minimal and focused on menu bar UX.
- Prefer clear, user-facing error messages over silent failures.
- Keep command execution code isolated from view code.
- Use SwiftUI-native controls and compact layouts.

## File Management

- Do not manually edit `project.pbxproj` to add/remove source files.
- New `.swift` files under `gh-auth-switcher/` are included automatically.
- Edit `project.pbxproj` only for build settings/target behavior.

## Runtime Notes

- The app depends on GitHub CLI (`gh`) being installed and available.
- Auth data comes from `gh auth status --json hosts`.
- Account switching uses:
  - `gh auth switch --hostname <host> --user <login>`
  - `gh auth setup-git --hostname <host>`
