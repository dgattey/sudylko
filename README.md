# Sudylko

Sudylko is an offline puzzle game for macOS and iOS, built with SwiftUI. Puzzles are generated locally from a puzzle number and difficulty (e.g. `#1384` on Medium). Custom puzzles use the number plus the difficulty picker in the sheet, not a suffix in the string.

## Requirements

- macOS 14+ (primary desktop build)
- iOS 17+ (iPhone and iPad via Xcode)
- Xcode 15+ or Swift 5.9+ toolchain

## Project layout

This repo is a Swift Package Manager app, not a web or Xcode-project monorepo.


| Path                           | Role                                           |
| ------------------------------ | ---------------------------------------------- |
| `Sources/Sudylko/`             | Main app (SwiftUI, menus, saves, achievements) |
| `Sources/SudylkoShared/`       | Shared types and dock icon rendering           |
| `Sources/SudylkoDockTilePlugin/` | `NSDockTilePlugIn` (quit-state Dock icon)    |
| `App/SudylkoDockTile/Info.plist` | Plug-in bundle metadata                      |
| `Sources/Sudylko/Engine/`      | `PuzzleGenerator`, `PuzzleSeed`, `SeededRNG`   |
| `App/Info.plist`               | Bundle metadata (`com.sudylko.mac`)            |
| `scripts/build-app.sh`         | Default build, icon, assemble `.app`, launch   |
| `scripts/generate-app-icon.sh` | Icon pipeline wrapper                          |
| `Sudylko.app`                  | Assembled debug bundle (gitignored)            |
| `iOS/Info.plist`               | Reference bundle metadata (`com.sudylko.ios`)  |
| `scripts/relaunch-mac.sh`      | Rebuild `.app`, quit, `open -n` (macOS verify loop) |
| `scripts/relaunch-ios.sh`      | `xcodebuild`, install, launch on default simulator   |
| `scripts/relaunch-all.sh`      | macOS then iOS relaunch in one command               |
| `scripts/build-ios.sh`         | Optional `xcodebuild` helper for iOS Simulator   |


## Build and run (macOS)

```bash
cd ~/repos/sudylko
./scripts/build-app.sh
```

The script:

1. Runs `swift build -c debug` (binaries under `.build/debug/`).
2. Assembles `Sudylko.app` in the repo root.
3. Copies bundled `App/Icon.icns` into the `.app` (regenerate manually with `scripts/generate-app-icon.sh` when needed).
4. Quits any running Sudylko and opens a fresh instance with `open -n`.

Use this script as the default verify loop after UI or behavior changes. A bare `open Sudylko.app` without rebuilding can show stale code.

## Quick relaunch (dev workflow)

After **macOS-only** changes (menus, dock icon, Mac-only views):

```bash
./scripts/relaunch-mac.sh
```

After **iOS-only** or **shared SwiftUI** (`SudylkoShared`, views on both platforms), relaunch iOS or both:

```bash
./scripts/relaunch-ios.sh
./scripts/relaunch-all.sh
```

`relaunch-mac.sh` runs `swift build -c debug`, assembles `Sudylko.app`, regenerates the icon, quits Sudylko, and opens a fresh instance with `open -n`. `relaunch-ios.sh` builds the **Sudylko** scheme for **iPhone 17 Pro (iOS 26.5)** by default, installs the `.app` on that simulator, and launches `com.sudylko.ios`. Override with `DESTINATION` or `SIM_UDID` if needed.



### Debug vs release

The **Debug** menu (unlock achievements, reset stats, delete all saves) and other `#if DEBUG` tooling only compile into **debug** builds. The script above builds debug on purpose.

For a release binary without debug tooling:

```bash
swift build -c release
```

There is no separate release packaging script yet. Distribution builds should use `-c release` and must not rely on the Debug menu.

## Build and run (iOS)

The same Swift package builds an iOS app when opened in Xcode:

1. Open `Package.swift` in Xcode (File → Open).
2. Select the **Sudylko** scheme and an **iPhone** or **iPad** simulator (or a connected device).
3. Run (⌘R).

Install the **iOS** platform in Xcode → Settings → Components if no simulator destinations appear.

Optional CLI build (requires a working Simulator destination):

```bash
./scripts/build-ios.sh
```

Override the simulator with `DESTINATION`, for example:

```bash
DESTINATION='platform=iOS Simulator,name=iPhone 15' ./scripts/build-ios.sh
```

### iOS vs macOS behavior

| Area | macOS | iOS |
|------|--------|-----|
| Entry | `SudylkoApp.swift` + app delegate | `SudylkoApp+iOS.swift` |
| Keyboard play | `BoardKeyboardHost` (digits, undo, space) | On-screen number pad |
| Home progress | Trailing `.inspector` | Sheet with `HomeProgressPaneView` |
| Dock / menu icon | `DockIconRenderer` + `SudylkoDockTile.docktileplugin` | Not used (stubs in `DockIconRenderer+iOS.swift`) |
| Window chrome | `WindowConfigurator`, unified toolbar | Standard navigation; sidebar collapses in-game |

Saves, achievements, puzzle generation, and settings use the same `UserDefaults` keys on both platforms.

## App Store and signing constraints

Sudylko is intended for Mac App Store distribution eventually. Avoid approaches that mutate the signed bundle at runtime or use non–App Store–eligible plugins.

**Do not use**

- `NSWorkspace.setIcon` (or similar) to rewrite the app bundle icon on disk.
- Runtime `iconutil` / bundle icon swapping.

**Dock icon (direct distribution)**

- One square bitmap in `DockIconRenderer.swift` (no custom squircle mask).
- **Running:** `applicationIconImage` (built-in Dock chrome).
- **Quit:** `SudylkoDockTile.docktileplugin` shows the same bitmap (accent from preferences).
- **Finder:** bundled `AppIcon.icns` (regen on `build-app.sh`).
- `NSDockTilePlugIn` is not Mac App Store–eligible.

Accent and light/dark appearance affect the generated icon. Re-run `build-app.sh` after changing accent defaults if you care about the on-disk icon matching.

## macOS UI architecture

### Home and game navigation

Home and in-game views are siblings in a `**ZStack`**, not a `NavigationStack` push. `NavigationStack` caused a solid toolbar on home, duplicate back buttons, and the game view drawing over home content.

The app shell is `NavigationSplitView`: sidebar (saves) | detail (home or active game). On home, `HomeView` fills the detail column with new-puzzle tiles and compact progress summary cards. On macOS, `ContentView` presents an attached trailing inspector via SwiftUI’s `.inspector(isPresented:content:)` (macOS 14+). On iOS, the same content appears in a sheet (`HomeProgressPresentationModifier`). The pane hosts `HomeProgressPaneView` (statistics or achievements). Summary cards toggle the pane; it closes when a game is active. See `ContentView.swift`, `HomeView.swift`, and `HomeProgressPaneView.swift`.

Home ↔ game transitions use a `ZStack` crossfade in `ContentView` (not `NavigationStack` push). There is a single back control in the detail toolbar while in-game.

### Toolbar

The window toolbar stays hidden in all modes, including fullscreen. Use `hiddenWindowToolbar()` from `ThemedWindowToolbar.swift` on root chrome.

### Accent color

SwiftUI `.tint` on the window group is not enough for every surface. The app uses:

- `AppAccentModel` plus `appAccentPropagation(_:)` on `WindowGroup` in `SudylkoApp.swift`.
- Environment keys in `AppAccentEnvironment.swift` (`appAccent`, `appAccentForeground()`, etc.).

Sheets and popovers need the propagation modifier or explicit environment if they should match the chosen accent. Mistake cells use a dedicated red fill so they stay visible when the user picks red as accent.

### Menus and keyboard shortcuts

SwiftUI `commands` define Settings, Undo/Redo, Delete, Sidebar, and Help. Many actions post `Notification.Name` values from `Notifications.swift` so `ContentView` can react without tight coupling.

**Help → Keyboard Shortcuts** uses ⇧? (Shift + `/` on US QWERTY). SwiftUI often rebuilds AppKit menus and clears key equivalents. `HelpMenuShortcutController` re-applies the shortcut on launch, activation, and each `applicationWillUpdate` in `SudylkoAppDelegate.swift`.

The board and escape keyboard hosts forward ⇧? via `SudylkoKeyEvent.isShiftQuestionMark` so the game does not swallow the shortcut.

**Edit menu** keeps Delete (wired through `EditMenuDeleteController` and `AppCommandState`). Cut, Copy, Paste, Select All, AutoFill, Dictation, and Emoji & Symbols are stripped via empty `CommandGroup` replacements plus `EditMenuCleaner.prune()`.

**View menu** tab-bar items are hidden with `CommandGroup(replacing: .toolbar)`.

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
| Reset achievements | Clears unlock IDs only                                      |
| Reset stats        | Clears lifetime stats only                                  |
| Delete all saves   | Removes all save blobs and index; returns home if in a game |


## Verifying changes

After any user-visible change:

1. Run `./scripts/build-app.sh`.
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

