# gh-auth-switcher

A simple macOS menu bar app to switch between authenticated GitHub CLI accounts and show a color badge for the active account.

## What it does

- Imports accounts automatically from `gh auth status --json hosts`
- Lets you switch account with one click
- Runs `gh auth setup-git` after switching
- Lets you assign one of 10 colors per account
- Shows the active account color as the menu bar badge
- **Git profile sync**: In Settings, pick a git profile per account; when you switch, `git config --global user.name` and `user.email` are updated. Profiles come from ~/.gitconfig and any [include]/[includeIf] files; you can also add custom profiles manually.

## Requirements

- macOS with Xcode 16+
- GitHub CLI installed (`gh`)
- At least one authenticated account (`gh auth login`)

## Build

From this folder:

```bash
xcodebuild -project "gh-auth-switcher.xcodeproj" -scheme "gh-auth-switcher" -configuration Debug -destination 'platform=macOS' build
```

If you hit a build database lock:

```bash
xcodebuild -project "gh-auth-switcher.xcodeproj" -scheme "gh-auth-switcher" -configuration Debug -destination 'platform=macOS' -derivedDataPath ".build/DerivedData" build
```

## Manual test checklist

- Launch app and confirm accounts are imported from `gh`
- Verify active account matches `gh auth status`
- Switch to a different account and confirm the command completes
- Verify menu bar badge color updates with the newly active account
- Assign custom colors and relaunch app to confirm colors persist
- Trigger a failure (e.g. uninstall/rename `gh`) and verify error messaging

## Known notes

- If `gh` is missing or not in PATH, the app shows an actionable error.
- `gh auth setup-git` can fail if local git credential setup is blocked; the error is shown inline.
