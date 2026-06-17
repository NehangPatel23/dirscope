# Dirscope

**Folder previews, built for Finder.**

Dirscope is a native macOS app and Quick Look extension that lets you browse folder and archive contents directly in Finder — press **Space** or **⌘Y** on any folder without opening a new window.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Overview

Finder’s built-in Quick Look preview for folders stops at a plain folder icon. Dirscope replaces that with a rich, interactive browser: sortable file lists, icon grids, expandable subfolders, zip archive browsing, and a side panel for previewing files — all inside the standard Quick Look panel.

The project consists of two targets:

| Target | Role |
|--------|------|
| **Dirscope** (host app) | Onboarding, settings, and extension setup |
| **FolderPreviewExtension** | Quick Look preview UI embedded in Finder |

Shared code (models, settings, theme, content loaders) lives in the `Shared/` folder and is compiled into both targets.

---

## Features

### Quick Look preview

- **Folder browsing** — list or icon view of any folder selected in Finder
- **Zip archive browsing** — open `.zip` files in Quick Look without extracting; expand folders and nested archives in-place using disclosure arrows; single-root wrapper folders are stripped so contents appear at the top level
- **Archive folder metadata** — files inside zips show per-entry size and modified date; folders show aggregated totals (sum of descendant file sizes) and the latest modified date among their contents
- **Sandbox-safe archive I/O** — in-process zip parsing and extraction (store + deflate) via `NSFileCoordinator`; no dependency on spawning `unzip` inside the extension sandbox
- **Sortable columns** — Name, Date Modified, Date Created, Size, Kind (and more via the column picker)
- **Customizable columns** — right-click column headers to show/hide metadata; default columns are Name, Modified, Size, and Type
- **File type icons** — every row in the Name column shows a proper folder or file icon (including archive entries)
- **Expandable folder tree** — auto-expand nested subfolders with configurable depth (1–7 levels); works for directories inside zip archives
- **Side-panel file preview** — select a file to preview text, Markdown, HTML, SVG, images, and other Quick Look–supported formats; dotfiles and config files (`.gitignore`, `.env`, `.dockerignore`, etc.) and code extensions (`.dart`, `.swift`, `.py`, …) show as monospaced source; archive entries are extracted on a background thread and scaled to fit the panel
- **Open files inside archives** — double-click or use **Open** in the side panel; the entry is staged and handed to the default app (see [Archive entry open](#archive-entry-open) below)
- **Footer toolbar** — path breadcrumb, item count, view switcher (List / Icons), and zoom slider
- **System appearance** — list, inspect panel, and footer use semantic `windowBackgroundColor` and refresh when macOS switches light/dark mode
- **No host app required for preview** — browsing and side-panel previews run entirely in the Quick Look extension; Dirscope’s window does not need to be open

### Host app

- **Dashboard** — quick-start overview and setup flow
- **Introduction** — friendly walkthrough of what Dirscope does
- **Extension setup** — step-by-step guide to enable the Quick Look extension in System Settings
- **Appearance settings** — default view, text size (S / M / L), and path breadcrumb
- **Behaviors settings** — hidden files, sort folders first, auto-expand subfolders, nesting depth
- **System Settings window** — same Appearance and Behaviors panes available via **⌘,**

### Settings sync

Settings are stored in a shared plist file inside the Quick Look extension’s sandbox container, so both the host app and extension read the same preferences — even without an App Group entitlement (which requires a paid developer certificate for ad-hoc builds).

Changes propagate live via Darwin notifications; no relaunch required. Preference writes are skipped when values are unchanged, and migrations run only in the host app (not during extension reload) to avoid feedback loops.

---

## Requirements

- **macOS 13.0** (Ventura) or later
- **Xcode 15+** (tested with Xcode 16 / macOS 26 SDK)
- Apple Silicon or Intel Mac

---

## Quick start

### Option A — install script (recommended)

From the project root:

```bash
./install-app.sh
```

This script:

1. Clears extended attributes on the project (`xattr -cr`) to avoid codesign failures
2. Regenerates app icons from the bundled source artwork (skip with `--skip-icons`)
3. Builds the project with `xcodebuild`
4. Installs `Dirscope.app` to `/Applications`
5. Syncs legacy preferences into the extension container (if present)
6. Reloads Quick Look (`qlmanage -r`)
7. Installs a LaunchAgent that runs `Dirscope -backgroundOpenHelper` at login (for archive file opens)
8. Opens the app (skip with `--no-open`)

```bash
./install-app.sh --no-open --skip-icons   # common for watch/hook rebuilds
```

### Option B — Xcode

1. Open `FolderPreviewApp.xcodeproj` in Xcode
2. Select the **FolderPreviewApp** scheme
3. Build and run (**⌘R**)
4. Enable **Dirscope** in **System Settings → General → Login Items & Extensions → Quick Look**

### Enable the extension

1. Open **System Settings → General → Login Items & Extensions**
2. Click **Quick Look** in the sidebar
3. Turn on **Dirscope**

Then select any folder in Finder and press **Space** or **⌘Y**.

---

## Usage

### Basic workflow

1. Highlight a folder or `.zip` archive in Finder
2. Press **Space** to open Quick Look
3. Browse files in list or icon view
4. Use disclosure arrows on folders (and zip archives inside archives) to expand nested contents
5. Click a file to preview it in the side panel — text, images, and other supported types, including files inside zip archives
6. Double-click a file to open it in its default app. Double-click a folder inside an archive to expand it (list view)

### Archive workflow

1. Quick Look a `.zip` file — Dirscope lists its contents like a folder
2. Expand subfolders with the chevron in the Name column
3. Select an image (e.g. `screen.png`) to preview it in the right panel without extracting the archive
4. Select text or code files for inline source preview; other types fall back to Quick Look where possible
5. Double-click a file (or select it and click **Open**) to launch it in its default application

### Archive entry open

Opening a file **inside** an archive works differently from browsing:

| Step | What happens |
|------|----------------|
| 1 | The Quick Look extension extracts that single entry to a shared staging folder |
| 2 | A pending-open request is written beside your preferences |
| 3 | A lightweight **background helper** (LaunchAgent) picks up the request and opens the staged file via Launch Services — no Dirscope window required |

You do **not** need Dirscope’s settings window open for Quick Look previews. A headless background helper (installed by `install-app.sh`) handles archive opens. The whole archive is never extracted — only the one file you chose.

After installing, the helper runs automatically at login. If archive opens stop working, reinstall with `./install-app.sh` to refresh the LaunchAgent.

**Return** also opens the selected archive entry when the preview panel has focus.

### Customizing the preview

Open Dirscope and go to **Configure → Appearance** or **Configure → Behaviors**, or use **⌘,** in the host app.

| Setting | Description |
|---------|-------------|
| Default view | Start in List or Icons view |
| Text size | Small, Medium, or Large — affects rows, labels, and grid icons |
| Show path breadcrumb | Footer path bar showing current location |
| Include hidden items | Show dotfiles (names starting with `.`) |
| Sort folders first | Keep directories above files when sorting |
| Auto-expand subfolders | Inline nested folder browsing |
| Maximum nesting depth | How many folder levels to expand (1–7) |

Right-click any column header in the preview to toggle visible metadata columns. The separate Preview/thumbnail column has been removed; file type icons always appear in the Name column.

---

## Project structure

```
Dirscope/
├── FolderPreviewApp/              Host app (SwiftUI)
│   ├── FolderPreviewAppApp.swift  App entry point
│   ├── ContentView.swift          Sidebar navigation shell
│   ├── AppSidebar.swift           Sidebar sections
│   ├── AppVisualKit.swift         Shared visual components (heroes, cards, panels)
│   ├── AppBranding.swift          App name, colors, icon helpers
│   ├── DashboardView.swift        Landing page
│   ├── IntroductionView.swift     Onboarding story cards
│   ├── ExtensionPageView.swift    Extension setup guide
│   ├── QuickLookPageView.swift    Quick Look usage guide
│   ├── SettingsPagesView.swift    Appearance & Behaviors pages
│   ├── AboutPageView.swift        About & capabilities
│   └── Settings/                  Settings form views
│
├── FolderPreviewExtension/        Quick Look extension (AppKit)
│   ├── PreviewViewController.swift   QL entry point
│   ├── FolderContentsTableView.swift List view
│   ├── FolderContentsCollectionView.swift  Icon grid view
│   ├── FilePreviewPaneView.swift     Side-panel file preview
│   ├── FileItemLauncher.swift        Double-click open (extracts archive entries)
│   ├── PreviewFooterView.swift       Path bar, view switcher, zoom
│   ├── FolderTreeModel.swift         Expandable folder tree
│   ├── ThumbnailProvider.swift       Inline thumbnail generation
│   └── FileIconCache.swift           Cached file type icons
│
├── Shared/                        Shared by app + extension
│   ├── PreviewSettings.swift      Settings accessors, defaults & migrations
│   ├── SharedPreferencesStore.swift  File-backed prefs + Darwin notifications
│   ├── FolderContentLoader.swift  Directory listing
│   ├── ArchiveContentLoader.swift Archive listing & entry extraction
│   ├── ArchiveEntryOpenBridge.swift Staged archive opens (extension → background helper)
│   ├── ArchiveSandboxAccess.swift Sandbox-safe archive reads & temp copies
│   ├── ZipArchiveReader.swift     In-process zip central-directory parser (store + deflate)
│   ├── FileItem.swift             File/folder/archive-entry model
│   ├── PreviewColumn.swift        Column definitions
│   ├── PreviewTheme.swift         Colors, fonts, layout constants
│   ├── InlineFilePreviewLoader.swift  Text/markdown/HTML preview
│   └── RichTextPreviewSupport.swift   Rendered Markdown/HTML helpers
│
├── scripts/
│   ├── generate-icons.sh          Regenerate AppIcon + AppMark assets
│   ├── rebuild-and-install.sh     Debounced rebuild (used by Cursor hook)
│   └── watch-and-install.sh       Filesystem watcher for continuous rebuilds
│
├── .cursor/
│   ├── hooks.json                 Rebuild after agent edits Swift/plist files
│   └── hooks/rebuild-after-edit.sh
│
├── install-app.sh                 Build, install, and reload Quick Look
└── FolderPreviewApp.xcodeproj     Xcode project
```

---

## Architecture notes

### Settings storage

Preferences are written to a plist at:

```
~/Library/Containers/com.folderpreview.app.preview/Data/Library/Application Support/Dirscope/Preferences.plist
```

The host app writes to this path explicitly (it is not sandboxed). The Quick Look extension reads and writes from its own Application Support directory, which resolves to the same location.

Legacy preferences at `~/Library/Application Support/Dirscope/Preferences.plist` are migrated automatically on first host-app launch. A one-time `displaySettingsMigratedV2` migration removes the deprecated Preview column from saved column layouts.

### Archive loading

Zip archives are read through `ArchiveSandboxAccess` (coordinated reads + temp copies in the extension container). Listing and extraction use `ZipArchiveReader` for store- and deflate-compressed entries. External tools (`unzip`, `tar`, `7z`) are used as fallbacks when in-process parsing is insufficient. Archive entries are represented as `FileItem` values with `isArchiveEntry = true` and a `relativePath` inside the archive.

### Archive entry open

The Quick Look extension is sandboxed and cannot open staged files in external apps directly. `ArchiveEntryOpenBridge` coordinates opens across processes:

```
Extension                          Host app (Dirscope)
─────────                          ───────────────────
extract entry → stage file
write PendingOpen.plist
post Darwin notify  ──────────────► background helper (LaunchAgent)
wake helper process ──────────────► if not already running
                                   NSWorkspace.open(staged file)
```

The sandboxed extension cannot open files in external apps directly, nor reliably cold-launch the full Dirscope UI. Instead, `install-app.sh` registers a user LaunchAgent (`com.folderpreview.app.openhelper`) that keeps a headless `Dirscope -backgroundOpenHelper` process available to receive Darwin notifications.

Staging and pending requests live under the extension container:

```
~/Library/Containers/com.folderpreview.app.preview/Data/Library/Application Support/Dirscope/
├── Preferences.plist
├── PendingOpen.plist          (written by extension, consumed by host)
└── OpenStaging/               (extracted files awaiting open)
```

The background helper retries pending opens on short delays to avoid races with the extension’s wake request. The main Dirscope window is not shown during archive opens.

### Quick Look appearance

The file list, right-hand inspect panel, and footer toolbar share the same semantic window background via `PreviewTheme.applySurfaceBackground`. Layer fills update in `viewDidChangeEffectiveAppearance` so the inspect pane and footer stay in sync with light/dark mode instead of retaining a one-time tint from panel load.

### Live settings updates

When settings change, `SharedPreferencesStore` posts:

- A `NotificationCenter` notification (in-process)
- A Darwin notify event (cross-process, for the extension)

The extension’s `PreviewViewController` observes both and reapplies settings without closing the Quick Look panel.

### Bundle identifiers

| Component | Identifier |
|-----------|------------|
| Host app | `com.folderpreview.app` |
| Quick Look extension | `com.folderpreview.app.preview` |

These are unchanged from early development; the user-facing name is **Dirscope**.

---

## Building from source

```bash
# Clone the repo
git clone https://github.com/NehangPatel23/dirscope.git
cd dirscope

# Build and install
./install-app.sh
```

Manual build:

```bash
xattr -cr .
./scripts/generate-icons.sh
xcodebuild \
  -project FolderPreviewApp.xcodeproj \
  -scheme FolderPreviewApp \
  -derivedDataPath ./DerivedData \
  build

open DerivedData/Build/Products/Debug/Dirscope.app
```

### Troubleshooting

| Problem | Fix |
|---------|-----|
| Quick Look still shows the default folder or zip icon | Close the panel, run `qlmanage -r`, then `killall Finder` if needed |
| "Extension … failed during preview of this document" | Reinstall with `./install-app.sh`, run `killall Finder`, try again; check `~/Library/Logs/DiagnosticReports/FolderPreviewExtension*.ips` |
| Archive list is empty or previews fail | Ensure the zip is readable; deflate entries require the in-process reader (rebuild if using an old build) |
| Double-click / Open inside archive does nothing | Reinstall with `./install-app.sh` (refreshes the LaunchAgent). Verify helper: `pgrep -fl backgroundOpenHelper` should show a running process |
| Settings changes not reflected in preview | Quit and reopen Quick Look; verify prefs exist at the container path above |
| Codesign error: "resource fork, Finder information, or similar detritus not allowed" | Run `xattr -cr DerivedData` in the project directory, then `./install-app.sh --no-open --skip-icons` (`install-app.sh` clears this automatically before each build) |
| Dock shows an old icon | Run `killall Dock` after reinstalling |
| Extension not listed in System Settings | Rebuild, reinstall, and ensure the appex is embedded in `Dirscope.app/Contents/PlugIns/` |

Inspect current preferences:

```bash
plutil -p ~/Library/Containers/com.folderpreview.app.preview/Data/Library/Application\ Support/Dirscope/Preferences.plist
```

---

## Development

### Auto rebuild and reinstall

Dirscope can rebuild and reinstall itself after source changes so the Quick Look extension stays up to date while you work.

**Option A — Cursor hook (agent edits):** `.cursor/hooks.json` runs `scripts/rebuild-and-install.sh` after Swift/plist edits. Reload Cursor once if hooks do not pick up immediately.

**Option B — File watcher (all edits):** run this in a terminal and leave it open:

```bash
./scripts/watch-and-install.sh
```

Both paths debounce changes (~3 seconds), install to `/Applications/Dirscope.app`, reload Quick Look, and log output to `DerivedData/install.log`. They call `./install-app.sh --no-open --skip-icons` so the app is not launched on every rebuild and icon regeneration is skipped (avoids a Python/Pillow dependency during rapid iteration).

Manual one-off install (opens the app when finished):

```bash
./install-app.sh
```

Faster rebuild without opening or regenerating icons:

```bash
./install-app.sh --no-open --skip-icons
```

### Regenerating icons

App icons are generated from `scripts/icon-source.png`. To regenerate:

```bash
./scripts/generate-icons.sh
```

Or pass a custom source:

```bash
./scripts/generate-icons.sh /path/to/icon-source.png
```

This produces:

- **AppIcon.appiconset** — opaque, full-bleed icons for macOS (Dock, Finder, About panel)
- **AppMark.imageset** — transparent squircle for in-app UI heroes

### Key files to know

| File | Purpose |
|------|---------|
| `Shared/PreviewSettings.swift` | All setting keys, accessors, and migrations |
| `Shared/SharedPreferencesStore.swift` | Cross-process preference persistence |
| `Shared/ZipArchiveReader.swift` | In-process zip listing and deflate extraction |
| `Shared/ArchiveContentLoader.swift` | Archive format dispatch, tree building, entry I/O |
| `Shared/ArchiveEntryOpenBridge.swift` | Staged archive opens from extension to host app |
| `FolderPreviewExtension/PreviewViewController.swift` | Quick Look lifecycle and layout |
| `FolderPreviewExtension/FilePreviewPaneView.swift` | Side-panel previews (folders, archives, images) |
| `FolderPreviewApp/AppVisualKit.swift` | Shared SwiftUI design system |

---

## Roadmap / known limitations

- **Zip** — listing, nested folders, nested zips, deflate extraction, image/text side-panel preview, per-entry **size/modified date** (including aggregated totals for implicit folders), and **open in default app** (via background helper) are implemented
- **Other archive formats** — `.tar`, `.tar.gz`, `.gz`, `.7z`, and `.rar` are partially wired (external-tool fallbacks) but not as reliable as zip in the sandboxed extension
- **HTML inside archives** — `code.html` and similar entries support Source/Formatted preview using a staged temp base URL; complex pages with external assets may still need a browser
- App Group entitlements are not used (requires a proper signing identity for distribution)
- Ad-hoc code signing is used for local development builds

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

Inspired by the concept of in-Finder folder previews. Built with Swift, SwiftUI, AppKit, and the Quick Look framework.
