<p align="center">
  <img src="WispTile%20logo.png" alt="WispTile app icon: a friendly ghost on a purple night sky" width="128" height="128">
</p>

<h1 align="center">WispTile</h1>

<p align="center">
  <strong>Free, open-source window manager for macOS that remembers your projects.</strong><br>
  Tile windows automatically, save your whole desktop per project, and restore it with one shortcut.
</p>

<p align="center">
  <a href="https://github.com/biswajitnk/WispTile/releases/latest">Download</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="https://github.com/biswajitnk/WispTile/issues">Report a bug</a> ·
  <a href="LICENSE">MIT License</a>
</p>

---

**WispTile** is a native macOS window manager and workspace manager in one app. It tiles your windows into layouts like halves, thirds and main + stack, and it remembers which apps, folders, URLs and window positions belong to each project. Switch from your coding project to your design project and every window goes back where it belongs, on one screen or across several monitors.

It is **100% free and open source** under the MIT License: no subscription, no license key, no account, and no tracking. Your projects stay on your Mac.

## Why WispTile?

Most Mac window tiling apps (like Rectangle, Magnet or Moom) arrange windows but forget your setup. Most workspace tools reopen apps but don't tile them or handle monitor changes. WispTile does both:

- **Project restore (Recall).** Capture your current desktop as a project, then restore every app, folder, browser URL and window position with one keyboard shortcut.
- **Automatic tiling.** Tile open windows into built-in layouts (Halves, Thirds, Main + Stack, Grid 2 × 2, Focus) or your own, with configurable gaps and screen-edge spacing. Turn on Auto-Tile and new windows snap into place.
- **Custom layout editor.** Draw, split, merge and resize zones on a grid to design your own tiling templates.
- **Per-project layouts.** Restore a project exactly as captured, or arrange its apps into any layout.
- **Multi-monitor and laptop aware.** Saves separate layouts for your desk (external display) and laptop screen, re-tiles after displays connect or disconnect, and keeps windows clear of the MacBook notch.
- **Safe by design.** A snapshot is saved before every restore so you can undo, call apps like Zoom and FaceTime are never moved, and existing windows are reused instead of duplicated.
- **Repair workspace.** Detects windows that drifted from your saved layout and snaps them back.
- **Menu bar and quick switcher.** Switch projects from the menu bar or with ⌃⌥1 to ⌃⌥9, and create a project from your open windows in one click.
- **Private.** No network calls, no analytics, no screen recording unless you turn on optional window previews.

## Requirements

- macOS 13 Ventura or later (Apple silicon and Intel)
- **Accessibility permission**, so WispTile can move and resize other apps' windows
- Optional: Screen Recording permission, only for real window previews

## Install

Download the latest `WispTile.dmg` or `.zip` from [Releases](https://github.com/biswajitnk/WispTile/releases/latest) and drag **WispTile** to your Applications folder.

Then grant Accessibility access: **System Settings › Privacy & Security › Accessibility**, add WispTile and turn it on. If you replace WispTile with a newer build, remove the old entry with **−** and add it again, because macOS ties the permission to each build.

> Release builds are not notarized yet. On first launch, Control-click WispTile and choose **Open**.

## Build from source

You need Xcode 26.4 or later (Swift 6.3 toolchain), as set in `Package.swift`.

```bash
git clone https://github.com/biswajitnk/WispTile.git
cd WispTile
swift build -c release
swift test
```

To make an app bundle, ZIP and DMG in `dist/`:

```bash
./Scripts/package_release.sh
```

The script signs the app ad-hoc by default. Set `DEVELOPER_ID_APPLICATION` to sign with your own Developer ID, and `APPLE_ID`, `TEAM_ID` and `APP_PASSWORD` to notarize.

There is also a command-line tool for scripting and testing:

```bash
swift run wisptile capture "My Project"
swift run wisptile list
swift run wisptile restore "My Project"
swift run wisptile tile thirds
```

## How to use

1. **Capture a project.** Arrange your apps the way you work, then choose **Capture Current Desktop**. Untick anything to leave out and name the project.
2. **Restore it.** Press its shortcut (⌃⌥1, ⌃⌥2 …), pick it in the menu bar, or click **Restore**. Use **Preview…** to see what will happen first.
3. **Tile windows.** Open **Layouts**, pick a layout and click **Tile Now**, or turn on **Auto-Tile**.
4. **Give a project a layout.** On the project's Layout card, choose a layout instead of **As captured**, then pick each app's zone in **Edit…**.
5. **Undo.** Every restore saves a snapshot first; click **Undo Restore** or restore any snapshot from **Snapshots**.

## Project structure

| Path | What it is |
| --- | --- |
| `Sources/WispTileCore` | Window, display, capture, restore, tiling, drift and snapshot engines (no UI) |
| `Sources/WispTileApp` | The SwiftUI and AppKit app: windows, menu bar, settings |
| `Sources/WispTileCLI` | The `wisptile` command-line tool |
| `Tests/WispTileCoreTests` | Unit tests for the core engines |
| `Scripts/package_release.sh` | Builds, signs and packages a release |
| `website/` | Static landing, support and privacy pages |

## Known limitations

- Snapping while dragging a window is not built yet.
- The display connect and disconnect rules on the Displays screen are saved but not acted on yet; "Re-tile after display changes" does work.
- Windows on other Spaces or in full screen can't be tiled until you switch to that desktop.
- Some apps have a minimum window size and can't shrink into narrow zones; WispTile tells you which ones.
- There is no automatic update check; watch the repository's Releases.

## Contributing

Bug reports, ideas and pull requests are welcome. Please [open an issue](https://github.com/biswajitnk/WispTile/issues) first for larger changes, run `swift test` before submitting, and describe how you tested on your Mac setup (number of displays, notch, macOS version).

## Privacy

WispTile is local-first. Projects, layouts and snapshots are stored as JSON in `~/Library/Application Support/WispTile`. It makes no network requests, collects no analytics, and never reads window contents. See [website/privacy.html](website/privacy.html).

## License

WispTile is released under the [MIT License](LICENSE). You are free to use, modify and share it, including commercially, as long as the copyright notice is kept.

---

<sub>Keywords: macOS window manager, Mac tiling window manager, window snapping, workspace manager, restore apps and windows, project workspaces, multi-monitor window layout, MacBook notch, free Rectangle alternative, free Magnet alternative, open source, Swift, SwiftUI.</sub>
