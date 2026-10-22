# Sudylko

Sudylko is an offline puzzle game for macOS and iOS, built with SwiftUI. Puzzles are generated locally from a puzzle number and difficulty (e.g. `#1384` on Medium). Custom puzzles use the number plus the difficulty picker in the sheet, not a suffix in the string.

## Requirements

- macOS 14+ (primary desktop build), iOS 17+ (iPhone and iPad)
- Xcode 26.5 toolchain and [mise](https://mise.jdx.dev) (`mise install` pins SwiftLint and Node)

## Project layout

Sudylko is a [DylKit](https://github.com/dgattey/dyl-kit) app: one SwiftPM executable target, with bundle, signing and release settings in `DylApp.toml`. There is no Xcode project.

| Path | Role |
| --- | --- |
| `Sources/Sudylko/` | The app (SwiftUI, menus, saves, achievements) |
| `Sources/Sudylko/Engine/` | `PuzzleGenerator`, `PuzzleSeed`, `SeededRNG` |
| `DylApp.toml` | Bundle IDs, platforms, icon, release feed and download-site settings |
| `scripts/generate-icon.swift` | Draws the app icon into `build/` for the bundler |
| `scripts/generate-sparkle-key.sh` | One-time Sparkle key pair setup |
| `server/` | The download site at sudylko.gattey.com, built on `@dylkit/web` |
| `run` | DylKit's entry point (`./run dev …`, `./run release …`), written by `./run dev sync` |

## Building, running and checking

DylKit's [`apple-dev-loop`](https://github.com/dgattey/dyl-kit/blob/main/skills/apple-dev-loop/SKILL.md) skill is the guide: `./run dev relaunch` builds `build/Sudylko Dev.app` and opens it in the background, `./run dev ios --run` does the same on the iOS Simulator, and `./run dev verify` runs what CI runs. Sudylko's `--initial-view` names are `game` and `settings/<page>` (`appearance`, `gameplay`, `software-updates`, `about`).

The **Debug** menu (unlock achievements, reset stats, delete all saves) and other `#if DEBUG` tooling only compile into debug builds, which is what `./run dev relaunch` builds.

## Releasing

Merging a PR to `main` releases Sudylko: the PR template's Release info box picks the version bump, and the `release` workflow builds, signs, and uploads it with its Sparkle feed. See DylKit's [`apple-release`](https://github.com/dgattey/dyl-kit/blob/main/skills/apple-release/SKILL.md) skill.

### iOS vs macOS behavior

| Area | macOS | iOS |
|------|--------|-----|
| Entry | `SudylkoApp.swift` + app delegate | `SudylkoApp+iOS.swift` |
| Keyboard play | `BoardKeyboardHost` (digits, undo, space) | On-screen number pad |
| Statistics and achievements | Sidebar panel picker | Same panel picker in the **Saves** sheet |
| Dock / menu icon | `DockIconRenderer` (live timer and accent while running) | Not used (stubs in `DockIconRenderer+iOS.swift`) |
| Window chrome | `WindowConfigurator`, unified toolbar | `NavigationStack`; the sidebar opens as a **Saves** sheet |
| Settings | Settings window (⌘,) | Settings sheet |

Saves, achievements, puzzle generation, and settings use the same `UserDefaults` keys on both platforms.

## App Store and signing constraints

Sudylko is intended for Mac App Store distribution eventually. Avoid approaches that mutate the signed bundle at runtime or use non–App Store–eligible plugins.

**Do not use**

- `NSWorkspace.setIcon` (or similar) to rewrite the app bundle icon on disk.
- Runtime `iconutil` / bundle icon swapping.

**Dock icon**

- One square bitmap in `DockIconRenderer.swift` (no custom squircle mask), set as `applicationIconImage` while Sudylko runs, in the chosen accent.
- Once Sudylko quits, the Dock and Finder show the bundled icon from `scripts/generate-icon.swift`.

## macOS UI architecture

### Home and game navigation

Home and in-game views are siblings in a **`ZStack`**, not a `NavigationStack` push. `NavigationStack` caused a solid toolbar on home, duplicate back buttons, and the game view drawing over home content.

The app shell is `NavigationSplitView`: sidebar (saves) | detail (home or active game). On home, `HomeView` fills the detail column with new-puzzle tiles. Statistics and achievements live in the sidebar. `SidebarPanelPicker` switches the sidebar between Games, Statistics (`PlayerStatsView`), and Achievements (`AchievementsListView`). On iOS, the same sidebar opens as a **Saves** sheet. See `ContentView.swift`, `HomeView.swift`, `AppSidebar.swift`, and `SidebarPanel.swift`.

Home ↔ game transitions use a `ZStack` crossfade in `ContentView` (not `NavigationStack` push). There is a single back control in the detail toolbar while in-game.

### Toolbar

The window toolbar background stays transparent in all modes, including fullscreen. In-game toolbar items (back, timer, archive, restart, settings) still show. Use `hiddenWindowToolbar()` from `ThemedWindowToolbar.swift` on root chrome.

### Accent color

SwiftUI `.tint` on the window group is not enough for every surface. The app uses:

- `AppAccentModel`, whose `palette` the `AppWindow` and `SettingsWindow` scenes install, plus `appAccentPropagation(_:)` on the window content in `SudylkoApp.swift`.
- Environment keys in `AppAccentEnvironment.swift` (`appAccent`, `appAccentForeground()`, etc.).

Sheets and popovers need the propagation modifier or explicit environment if they should match the chosen accent. Mistake cells use a dedicated red fill so they stay visible when the user picks red as accent.

### Menus and keyboard shortcuts

SwiftUI `commands` define Undo/Redo, Delete, Sidebar, and Help. DylKit's `AppWindow` adds Check for Updates… and `SettingsWindow` adds Settings… (⌘,). Many actions post `Notification.Name` values from `Notifications.swift` so `ContentView` can react without tight coupling.

**Help → Keyboard Shortcuts** uses ⇧? (Shift + `/` on US QWERTY), declared with `.keyboardShortcut("?", modifiers: .shift)`.

**Edit menu** keeps Delete (enabled from `AppCommandState`). Cut, Copy, Paste, and Select All are removed with empty `CommandGroup` replacements. Dictation and Emoji & Symbols are added by AppKit itself, so `SudylkoAppDelegate` turns them off with defaults keys at launch.

**Debug menu** (debug builds) is built in AppKit by `DebugMenuController`. SwiftUI drops it whenever it rebuilds the main menu, so the controller re-adds it after each app update.

**View menu** tab-bar items are hidden by `NSWindow.allowsAutomaticWindowTabbing = false` in `SudylkoAppDelegate.swift`.

### Glass and materials

Sidebar and quick-start tiles use `glassSidebar` / `glassPanel` in `VisualEffectBackground.swift` with the user-selected `WindowBackgroundMaterial` from settings.

## Persistence

### Saves

- Index key: `savedGameIDs`
- Per-save blobs: `savedGame.<uuid>`
- Format: JSON `SavedGameState` with `puzzleNumber`, `difficulty`, grid state, timer fields, `createdAt`, `savedAt`

There is no backward-compatibility layer for older save formats. Invalid JSON is skipped when loading.

### Achievements and statistics

Lifetime data lives separately from save files:

- Unlocked achievements: `achievementUnlockedIDs`
- Stats: `achievementLifetimeStats` (`PlayerLifetimeStats`)

Archiving a save does not remove achievements or lifetime stats. Abandoned in-progress archives increment loss stats and can unlock achievements.

Achievement order in the UI and Debug menu is `AchievementID.displayOrder` (easier / earlier first).

### Debug menu actions


| Item               | Effect                                                      |
| ------------------ | ----------------------------------------------------------- |
| Unlock achievement | Unlocks one achievement and shows celebration               |
| Unlock multiple    | Unlocks a sample batch or every achievement                 |
| Pulse animation    | Plays a board pulse (puzzle complete, row, column, box, or digit) |
| Reset achievements | Clears unlock IDs only                                      |
| Reset stats        | Clears lifetime stats only                                  |
| Reset all progress | Clears unlock IDs, lifetime stats, and all saves            |
| Seed done game     | Adds a finished save for sidebar and end-state testing      |
| Delete all saves   | After confirmation, removes all save blobs and index; returns home if in a game |


## Verifying changes

After any user-visible change:

1. Run `./run dev relaunch` (or `./run dev capture --appearance light|dark` for a screenshot).
2. Exercise the affected flow in the running app (menus, navigation, accent, fullscreen, saves).
3. For visual work, compare against the intended appearance in both light and dark mode. Builds succeeding is necessary but not sufficient.

User-attached screenshots under the Cursor workspace `assets/` folder are the ground truth when debugging layout or color regressions.

## Agent / contributor notes

- Grep and read under `Sources/**/*.swift`, not `*.{ts,tsx}`.
- Prefer deleting dead code over keeping migration shims. This app has not shipped. Do not add `purgeObsoleteDefaults`-style cleanup unless there is a concrete key to remove.
- Do not reintroduce per-difficulty save slots (`savedGame.easy`, etc.), `seedPhrase` in saves, or puzzle-id strings with difficulty suffixes (`#1384-E`). Parse numbers only. Difficulty comes from UI state.
- Large navigation or window-chrome changes deserve a design pass before coding. The `NavigationStack` detour in this repo required multiple user-reported regressions to unwind.
- When fixing macOS menu shortcuts, assume SwiftUI will rebuild menus. Fix the rebuild loop, do not stack multiple partial patches.
- Pin App Store / sandbox constraints before implementing icon or bundle mutation features.

