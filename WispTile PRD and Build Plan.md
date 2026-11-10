# WispTile: PRD and Build Plan

Nov 7, 2026

> **Update:** WispTile is now free and open source under the MIT License. Every feature is free; there is no purchase, license key, trial or seat limit, and updates are published on GitHub Releases. The licensing, pricing and Sparkle sections below describe the original commercial plan and are kept for history.

## Overview

WispTile is a macOS app that remembers the apps, files, tabs and window positions for each project, puts them back with one shortcut, and keeps windows tiled while you work. It is a one-time purchase (no free trial, no subscription), sold directly and not through the Mac App Store.

**The problem.** Switching between projects means reopening the same apps, finding the same files and dragging windows into place again. Multi-monitor setups make it worse: unplug a display and everything piles onto the laptop screen. Existing window managers tile but forget; existing workspace tools remember but don't tile.

**The pitch.** One app does both. Tiling is the always-on engine, and Recall (project restore) is the layer on top. Capture a desktop once, then restore it, switch projects, or adapt to a new monitor setup in one step, without closing or duplicating anything.

## Users and positioning

The first customers are people who run several projects on one Mac and are tired of rebuilding their desktop: developers, designers, content creators and anyone with a multi-monitor desk.

| User | Job to be done | Pain today |
| --- | --- | --- |
| Developer with 2–3 projects | Open the right editor, terminal, browser tabs and docs for a project in one step | Rebuilds the setup after every switch or reboot |
| Content creator on multiple screens | Switch between a content project and a different work project without losing layouts | Windows land on the wrong display after plugging in |
| Laptop and desk user | Same project works at the desk and on the laptop | Display changes scramble every window |
| Power user who already tiles | Keep tiling but add memory of what belongs together | Tiling tools forget the project |

**How it differs.** Window managers (Rectangle, Magnet, Moom) tile but do not remember projects. Workspace tools restore apps but do not tile or adapt to displays. This app treats the project as the unit and the display setup as a property of that project.

## Goals and non-goals

v1 succeeds if a user can capture a project, restore it in one step, and trust the app not to break their windows.

**Goals**

- Capture and restore a project's apps, folders, tabs and window positions in under 5 seconds on a typical setup.
- Always-on tiling with drag-to-draw custom templates.
- Adapt layouts when displays connect or disconnect, including Macs with a notch.
- Quick project switch from the menu bar and a keyboard shortcut.
- Direct sale with license-key activation and in-app updates that notify even when the app window is closed.

**Non-goals for v1**

- Windows or Linux support.
- Cloud sync or team sharing of projects.
- Mac App Store distribution (its sandbox blocks window control).
- Recording or restoring app-internal state beyond what apps expose (files, folders, URLs).

## Feature requirements

P0 ships in v1, P1 follows within two releases, P2 is later. Screens refer to the design canvas boards.

| Area | Requirement | Priority | Design board |
| --- | --- | --- | --- |
| Capture | Capture open windows into a project: apps, folders, URLs, window frames, display setup; choose what to include; Current Space or original Spaces | P0 | Capture current desktop |
| Restore | Restore a project with a preview of what will launch, move or be skipped; reuse existing windows; no duplicates | P0 | Restore preview, Restore report |
| Quick switch | Switch project from the menu bar or ⌥ shortcuts; stackable screen icons show how many displays a project uses | P0 | Menu bar |
| Quick create | When windows are not in a project, offer to create one from them | P0 | Menu bar |
| Tiling engine | Always-on tiling: snap zones while dragging, keyboard tiling, gap and edge padding, never-tile app list | P0 | Snapping and spacing |
| Templates | Draw custom tiling templates by dragging zones; save, edit, per-display | P0 | Custom template editor |
| Displays | Detect connect and disconnect, adapt layout, ask first or apply automatically; handle notch | P0 | Monitor adaptation |
| Drift | Detect when windows moved away from the saved layout and offer repair | P1 | Repair workspace |
| Snapshots | Automatic snapshot before every restore; manual snapshots; undo restore | P0 | Snapshots |
| Rules | Safety rules and automation (display connect, open folder, call starts) | P1 | Rules |
| Project editing | Add or remove apps, folders and URLs; per-app behavior; color, shortcut, duplicate, delete | P0 | Edit project |
| Shortcuts | Customizable global shortcuts with conflict warnings; quick switcher palette | P1 | Keyboard shortcuts |
| Licensing | License-key activation, seats, offline grace, deactivate a Mac | P0 | Activate license, License settings |
| Updates | Automatic update check; slide-in notification even when the app window is closed | P0 | Update window, Update notification |
| Onboarding | Welcome, Accessibility permission request, empty state, first capture | P0 | Welcome, Allow window control, Empty state |
| Errors | Permission revoked, partial restore, offline, seats full | P0 | Errors and edge cases |
| Settings | Profile, general, notifications, privacy, export, about | P1 | Settings and profile |
| Dark mode | Full dark appearance | P2 | Not designed yet |
| Accessibility | VoiceOver labels and full keyboard navigation | P1 | Not designed yet |
| Automation hooks | Shortcuts and AppleScript actions; switch by Focus mode or git branch | P2 | Not designed yet |

## Key user flows

1. **First run.** Welcome, then Accessibility permission, then "Capture Current Desktop" or start from a layout. The empty state stays until the first project exists.
2. **Capture.** Review detected windows, untick what to leave out, name the project, choose Current Space or original Spaces, create.
3. **Restore.** Press the project shortcut. The app shows a preview, takes an automatic snapshot, launches missing apps, moves existing windows, and shows a report with anything skipped and an undo.
4. **Switch.** Open the menu bar list or press ⌥ plus the project number. The current project is saved as a snapshot first.
5. **Display change.** On connect or disconnect the app asks, or applies the saved layout, depending on the rule. Nothing is closed.
6. **No license yet. There is no trial: first launch opens Activate WispTile, and nothing runs until a valid key is entered. Buy a License opens the website checkout**.
7. **Update.** A background helper checks for updates. When one is found the app slides in a notification even if its window is closed; the user installs now or later.

## Technical architecture

A native Swift app (SwiftUI and AppKit) with a small background helper for the menu bar and updates. All window control goes through the macOS Accessibility API.

&#91;embedded content: architecture · 3 layers, 3 side components\]

Screens call the core engine, which is the only layer that talks to macOS. The helper and local storage both connect to the engine, not to the screens.

| Concern | Choice |
| --- | --- |
| Window read and move | Accessibility API (AXUIElement) for frames, titles and raise; CGWindowList to match windows to apps |
| Launching and files | NSWorkspace to open apps, folders and URLs; per-app handlers for opening a project folder in editors and terminals |
| Displays | NSScreen with visibleFrame (the area below the menu bar) and safeAreaInsets for the notch; a display-change notification triggers the adapt rule |
| Tiling | Own engine: zones as percentages of the visible frame, applied with gaps and padding; drag detection through an event tap |
| Shortcuts | Global hotkeys through a hotkey library built on the Carbon hotkey API |
| Menu bar and login | NSStatusItem in the helper, registered with SMAppService as a login item |
| Spaces | Public APIs do not move windows between Spaces; v1 restores to the current Space and treats "original Spaces" as best effort |
| Storage | JSON files in the app support folder; license and secrets in the Keychain |
| Updates and licensing | Sparkle plus a hosted license service |
| Distribution | Developer ID signed, hardened runtime, notarized; not sandboxed |

## Data model

Everything is stored locally as JSON files in the app's support folder. Zones are stored as percentages of a display's usable area, so layouts survive resolution changes and notch differences.

| Entity | Key fields |
| --- | --- |
| Project | id, name, color, shortcut, items (apps, folders, URLs, per-app behavior), layouts (one per display setup), restore options (Spaces, fullscreen rule) |
| Layout | display signature (count, sizes), zones with app assignment as percentages, template id |
| Template | id, name, zones (x, y, width, height in percent), optional per-display variants |
| Snapshot | id, time, kind (auto or manual), window frames, display setup, source project |
| Rule | trigger (display connect, folder open, call start), action, enabled |
| Settings | login item, menu bar and Dock visibility, shortcuts, gaps and padding, never-tile apps, appearance |
| License | key, seat id, last check time, status, plan; stored in the Keychain |

## Licensing and updates

Use a hosted license service (Paddle, Lemon Squeezy or Keygen) for payment, keys and seats, and Sparkle for updates. Do not build either from scratch.

**License flow**

- There is no trial and no subscription. A valid license key is required before the app does anything; first launch shows Activate WispTile.
- The user enters a key; the app activates a seat for this Mac and stores a signed license in the Keychain.
- The plan covers a set number of Macs. A user can deactivate a Mac from the app or the account page.
- The app re-checks the license in the background. If it is offline it keeps working for a grace period (25 days after a 30-day check window is the working proposal), then asks to check again.
- Refunds and chargebacks revoke the key on the next check.

**Update flow**

- Sparkle checks an appcast feed on a schedule. Updates are signed and notarized.
- A small menu-bar helper, registered as a login item, performs the check even when the main window is closed.
- When an update is found, the helper shows a slide-in notification with the version, a short note, "Install" and "Later". Critical fixes can be marked required.
- Release notes are shown in the update window before install.

## Permissions, privacy and security

- **Accessibility permission** is required to read and move other apps' windows. The app asks once, explains why, and shows a clear state if macOS later revokes it.
- **Automation permission** is requested per app only when an app needs it (for example to open a Finder folder or a Terminal directory).
- **No window content is read.** The app stores window titles only where needed to match windows, never screen contents.
- **Local-first.** Projects, layouts and snapshots stay on the Mac. The only network calls are license checks, update checks and optional diagnostics.
- **Analytics are off by default.** Optional usage data never includes window titles or file paths.
- **Hardened runtime, signing and notarization** for every release; license data in the Keychain; update packages signed with Sparkle's EdDSA key.

**Window previews (optional, off by default)**

- Default: schematic previews drawn from saved zone geometry. No extra permission and nothing captured.
- Opt-in: Settings > Privacy and Data > Show real window previews. This needs the Screen Recording permission (a separate step from Accessibility, with its own explainer screen).
- Capture: one still image per window with ScreenCaptureKit, taken when a project is captured or restored. Stored locally, never uploaded. Live thumbnails only while the quick switcher is open.
- Fallbacks: minimized windows, windows on other Spaces and protected content can come back blank or stale. Show the app icon and window title on a neutral tile instead of an empty white box.
- Copy: the Allow window control screen no longer says WispTile cannot record the screen. It says window previews are optional and off by default.

**Keyboard shortcuts**

- Global hotkeys use RegisterEventHotKey or the KeyboardShortcuts package. They work without Accessibility; the actions they trigger (moving windows) need it.
- Defaults are user-changeable, with a conflict warning when a combo is taken. Avoid shipping Ctrl+Opt with arrow keys as-is (Rectangle, Magnet and Mission Control use them) and avoid bare Opt+1 to Opt+9, which blocks typing characters like ¡ and ™. Prefer Ctrl+Opt with a number for project switching.
- Direct-download build only. The App Store sandbox blocks window control.

## Build phases

A solo build takes about 18 to 24 weeks to a public launch. Each phase ends with a gate that must pass before the next starts. Week counts are estimates.

&#91;embedded content: roadmap · 7 phases with gates\]

A phase starts only when the gate before it has passed; the table below lists what each phase delivers.

| Phase | Weeks | Deliverables | Exit gate |
| --- | --- | --- | --- |
| 0. Spike | 1–2 | Prove window move and resize through Accessibility on the target apps; display-change events; notch visible frame; global hotkey | A script restores 3 apps across 2 displays without duplicates |
| 1. Core engine | 4 | Tiling engine, template model, capture, restore, snapshots, undo | Capture then restore works for the supported app list on a real desk |
| 2. App shell | 4 | Main window, sidebar, project list and editor, capture flow, template editor, menu bar quick switch and quick create, onboarding and permission | Boards 1–8 and 19–23 work end to end |
| 3. Displays and safety | 3 | Display adaptation, rules, drift repair, restore preview and report, error states, shortcuts screen | A display unplug and replug test passes on notched and non-notched Macs |
| 4. Licensing and updates | 3 | License service, activation, seats, offline grace, Sparkle, background update notification, website and checkout | A fresh Mac goes from download to paid and activated to updated |
| 5. Beta and hardening | 4 | 20-person beta, crash reporting, compatibility list, performance and polish, accessibility pass | No known data-loss bugs; crash-free sessions at least 99% |
| 6. Launch | 1–2 | Landing page, demo video, release notes, support page, public release | Version 1.0 signed, notarized and live |

## Testing and QA

Window management fails in ways that only show up on real setups, so test on real hardware early.

| Area | What to test |
| --- | --- |
| Hardware matrix | Notched and non-notched MacBooks; one, two and three displays; mixed resolutions and scaling |
| macOS versions | Current release and the two before it |
| App compatibility | Browsers, editors, terminals, Electron apps, Finder, Slack, Zoom, Figma, Android Studio, Xcode |
| Edge cases | Fullscreen apps, Stage Manager, multiple Spaces, minimized windows, apps that ignore resize, apps not installed, moved folders |
| Restore safety | No duplicate windows, nothing closed, undo returns the exact previous frames |
| Licensing | Fresh install, activation, offline grace, seat limit, deactivate, refund |
| Updates | Update with the window closed, required updates, a failed download |
| Permissions | First grant, revoked while running, never granted |

Before each release: a 20-person beta for at least two weeks, with crash reporting on, and a short checklist run on a notched and a non-notched Mac.

## Launch, pricing and distribution

- **Distribution:** sold directly from a website, notarized and signed, with a license service handling checkout and keys. Not in the Mac App Store for v1.
- **Pricing (proposal, to test):** one-time purchase with no free trial and no subscription; one license covers 2 Macs. How long free updates last (one major version or lifetime) is an open decision below.
- **Launch channels:** a landing page with a short demo, Product Hunt, developer and design communities, and a small waitlist from the beta.
- **Support:** a help page, an in-app diagnostics export, and an email address.
- **Website needs:** demo video, pricing, download, account page for license and seats, release notes and the appcast feed.

## Success metrics

Targets are starting points to review after the beta.

| Metric | Target |
| --- | --- |
| Activation: captured a first project within the first session | 60% of new installs |
| Restore success: all selected windows placed without errors | 95% of restores |
| Week-4 retention of new customers | 35% |
| Website visit to purchase conversion | 8% |
| Crash-free sessions | 99.5% |
| Support requests per 100 active users per month | under 3 |

## Risks and open decisions

| Risk or decision | Impact | Plan |
| --- | --- | --- |
| Apps that ignore resize or position through Accessibility | Some windows will not tile or restore | Keep a per-app compatibility list; report skipped windows; allow "never tile" |
| macOS changes to window or permission APIs | Features can break on a new release | Test betas early; ship fast point releases |
| Spaces and Stage Manager are only partly scriptable | Restore to the original Space may be unreliable | v1 default is Current Space; Original Spaces labelled as best effort |
| Mac App Store excluded | Less discovery | Compensate with direct marketing and a strong website |
| Restoring file or tab state depends on each app's support | Not every app can reopen the same content | Support a defined list of apps first; show clearly what each app restores |
| Pricing model (one-time vs yearly) | Revenue and support load | Decision needed before launch; test on the beta waitlist |
| Free-update period (one major version or lifetime) and offline grace period | Piracy vs friction | Decision needed; start with 14 days and the grace period above |
| Windows version | Larger market, large extra work | Out of scope for v1; revisit after launch |
