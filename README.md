# Dirscope

**Folder previews, built for Finder.**

Dirscope is a native macOS app and Quick Look extension that lets you browse folder and archive contents directly in Finder — press **Space** or **⌘Y** on any folder without opening a new window.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Overview

Finder’s built-in Quick Look preview for folders stops at a plain folder icon. Dirscope replaces that with a rich, interactive browser: sortable file lists, icon grids, inline thumbnails, expandable subfolders, archive browsing, and an optional side panel for previewing documents — all inside the standard Quick Look panel.

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
- **Archive support** — browse `.zip` archives without extracting (additional formats registered; zip is fully implemented)
- **Sortable columns** — Name, Date Modified, Date Created, Size, Kind
- **Customizable columns** — right-click column headers to show/hide metadata
- **Inline thumbnails** — optional icon column with previews for images, PDFs, SVGs, and more
- **Expandable folder tree** — auto-expand nested subfolders with configurable depth (1–7 levels)
- **Side-panel file preview** — select a file to preview text, Markdown, HTML, SVG, and Quick Look–supported formats inline
- **Footer toolbar** — path breadcrumb, item count, view switcher (List / Icons), and zoom slider
- **Dark mode** — adapts to system appearance

### Host app

- **Dashboard** — quick-start overview and setup flow
- **Introduction** — friendly walkthrough of what Dirscope does
- **Extension setup** — step-by-step guide to enable the Quick Look extension in System Settings
- **Appearance settings** — default view, text size (S / M / L), path breadcrumb, thumbnails
- **Behaviors settings** — hidden files, sort folders first, auto-expand subfolders, nesting depth
- **System Settings window** — same Appearance and Behaviors panes available via **⌘,**

### Settings sync

Settings are stored in a shared plist file inside the Quick Look extension’s sandbox container, so both the host app and extension read the same preferences — even without an App Group entitlement (which requires a paid developer certificate for ad-hoc builds).

Changes propagate live via Darwin notifications; no relaunch required.

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

1. Regenerates app icons from the bundled source artwork
2. Builds the project with `xcodebuild`
3. Installs `Dirscope.app` to `/Applications`
4. Syncs legacy preferences into the extension container (if present)
5. Reloads Quick Look (`qlmanage -r`)
6. Opens the app

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

1. Highlight a folder (or `.zip` archive) in Finder
2. Press **Space** to open Quick Look
3. Browse files in list or icon view
4. Click a file to preview it in the side panel (when available)
5. Double-click any item to open it in its default app

### Customizing the preview

Open Dirscope and go to **Configure → Appearance** or **Configure → Behaviors**, or use **⌘,** in the host app.

| Setting | Description |
|---------|-------------|
| Default view | Start in List or Icons view |
| Text size | Small, Medium, or Large — affects rows, labels, and grid icons |
| Show path breadcrumb | Footer path bar showing current location |
| Show file thumbnails | Icon column in list view |
| Include hidden items | Show dotfiles (names starting with `.`) |
| Sort folders first | Keep directories above files when sorting |
| Auto-expand subfolders | Inline nested folder browsing |
| Maximum nesting depth | How many folder levels to expand (1–7) |

Right-click any column header in the preview to toggle visible metadata columns.

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
│   ├── PreviewFooterView.swift       Path bar, view switcher, zoom
│   ├── FolderTreeModel.swift         Expandable folder tree
│   ├── ThumbnailProvider.swift       Inline thumbnail generation
│   └── FileIconCache.swift           Cached file type icons
│
├── Shared/                        Shared by app + extension
│   ├── PreviewSettings.swift      Settings accessors & defaults
│   ├── SharedPreferencesStore.swift  File-backed prefs + Darwin notifications
│   ├── FolderContentLoader.swift  Directory listing
│   ├── ArchiveContentLoader.swift Zip archive listing
│   ├── FileItem.swift             File/folder model
│   ├── PreviewColumn.swift        Column definitions
│   ├── PreviewTheme.swift         Colors, fonts, layout constants
│   └── InlineFilePreviewLoader.swift  Text/markdown/HTML preview
│
├── scripts/
│   └── generate-icons.sh          Regenerate AppIcon + AppMark assets
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

Legacy preferences at `~/Library/Application Support/Dirscope/Preferences.plist` are migrated automatically by `install-app.sh`.

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
| Quick Look still shows the default folder icon | Close the panel, run `qlmanage -r`, try again |
| Settings changes not reflected in preview | Quit and reopen Quick Look; verify prefs exist at the container path above |
| Codesign error: "resource fork, Finder information, or similar detritus not allowed" | Run `xattr -cr .` on the project directory before building |
| Dock shows an old icon | Run `killall Dock` after reinstalling |
| Extension not listed in System Settings | Rebuild, reinstall, and ensure the appex is embedded in `Dirscope.app/Contents/PlugIns/` |

Inspect current preferences:

```bash
plutil -p ~/Library/Containers/com.folderpreview.app.preview/Data/Library/Application\ Support/Dirscope/Preferences.plist
```

---

## Development

### Regenerating icons

App icons are generated from a source image bundled in the Cursor assets folder. To regenerate:

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
| `Shared/PreviewSettings.swift` | All setting keys and accessors |
| `Shared/SharedPreferencesStore.swift` | Cross-process preference persistence |
| `FolderPreviewExtension/PreviewViewController.swift` | Quick Look lifecycle and layout |
| `FolderPreviewApp/AppVisualKit.swift` | Shared SwiftUI design system |

---

## Roadmap / known limitations

- Archive browsing is fully implemented for **zip**; other registered formats (tar, gz, 7z, rar) are detected but not yet parsed
- App Group entitlements are not used (requires a proper signing identity for distribution)
- Ad-hoc code signing is used for local development builds

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

Inspired by the concept of in-Finder folder previews. Built with Swift, SwiftUI, AppKit, and the Quick Look framework.
