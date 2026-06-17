# Dirscope — Developer Guide

Technical documentation for contributors and maintainers. For install, features, and user-facing fine print, see the [main README](../README.md).

---

## Requirements

| Requirement | Notes |
|-------------|--------|
| **macOS 13.0+** (Ventura) | Quick Look extension target |
| **Xcode 15+** | Tested with Xcode 16 / macOS 26 SDK |
| **Apple Silicon or Intel** | Universal build |
| **Pillow** (optional) | `pip install Pillow` — only for `scripts/generate-icons.sh` |
| **7zz** (optional) | `./scripts/fetch-7zz.sh` — bundled into app for sandboxed 7z/rar |

---

## Project structure

Dirscope is two Xcode targets plus shared code:

| Target | Role |
|--------|------|
| **Dirscope** (`FolderPreviewApp`) | Host app — onboarding, settings, extension setup |
| **FolderPreviewExtension** | Quick Look preview UI embedded in Finder |

Shared models, settings, theme, and content loaders live in `Shared/` and compile into both targets.

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
│   ├── PreviewFooterView.swift       Path bar, item count, view switcher, zoom
│   ├── FolderTreeModel.swift         Expandable folder tree
│   ├── ThumbnailProvider.swift       Inline thumbnail generation
│   └── FileIconCache.swift           Cached file type icons
│
├── Shared/                        Shared by app + extension
│   ├── PreviewSettings.swift      Settings accessors, defaults & migrations
│   ├── SharedPreferencesStore.swift  File-backed prefs + Darwin notifications
│   ├── FolderContentLoader.swift  Directory listing
│   ├── ArchiveContentLoader.swift Archive listing & entry extraction
│   ├── ArchiveEntryOpenBridge.swift Staged archive opens (extension → helper)
│   ├── ArchiveSandboxAccess.swift Sandbox-safe archive reads & temp copies
│   ├── ZipArchiveReader.swift     In-process zip parser (store + deflate)
│   ├── TarArchiveReader.swift     In-process tar/gz; xz via subprocess
│   ├── FileItem.swift             File/folder/archive-entry model
│   ├── PreviewColumn.swift        Column definitions
│   ├── PreviewTheme.swift         Colors, fonts, layout constants
│   ├── InlineFilePreviewLoader.swift  Text/code preview detection
│   └── RichTextPreviewSupport.swift   Rendered Markdown/HTML helpers
│
├── docs/
│   └── DEVELOPMENT.md             This file
│
├── scripts/
│   ├── generate-icons.sh          Regenerate AppIcon + AppMark assets
│   ├── fetch-7zz.sh               Download or copy 7zz into Vendor/
│   ├── release-build.sh           Release build, optional notarization
│   ├── rebuild-and-install.sh     Debounced rebuild (Cursor hook)
│   └── watch-and-install.sh       Filesystem watcher for continuous rebuilds
│
├── Vendor/
│   └── README.md                  7-Zip bundling notes (binary gitignored)
│
├── .cursor/
│   ├── hooks.json                 Rebuild after agent edits Swift/plist files
│   └── hooks/rebuild-after-edit.sh
│
├── install-app.sh                 Build, install, and reload Quick Look
└── FolderPreviewApp.xcodeproj     Xcode project
```

---

## `install-app.sh` — what it does

From the project root:

```bash
./install-app.sh
```

The script runs these steps in order:

1. **Clear extended attributes** (`xattr -cr`) on `DerivedData` and source folders to avoid codesign “resource fork” failures
2. **Regenerate icons** from `scripts/icon-source.png` (skipped with `--skip-icons`, or when Pillow is missing)
3. **Build** with `xcodebuild` → `DerivedData/Build/Products/Debug/Dirscope.app`
4. **Bundle `7zz`** into app Resources when `Vendor/7zz/7zz` exists (or after `fetch-7zz.sh`)
5. **Install** to `/Applications/Dirscope.app`
6. **Sync legacy preferences** from `~/Library/Application Support/Dirscope/Preferences.plist` into the extension container (if present)
7. **Reload Quick Look** (`qlmanage -r`)
8. **Install LaunchAgent** `com.folderpreview.app.openhelper` → `Dirscope -backgroundOpenHelper` at login
9. **Open the app** (skipped with `--no-open`)

Fast iteration:

```bash
./install-app.sh --no-open --skip-icons
```

---

## Architecture

### Settings storage

Preferences are written to a plist at:

```
~/Library/Containers/com.folderpreview.app.preview/Data/Library/Application Support/Dirscope/Preferences.plist
```

The host app writes to this path explicitly (it is **not** sandboxed). The Quick Look extension reads and writes from its own Application Support directory, which resolves to the same location.

**Legacy migration:** `~/Library/Application Support/Dirscope/Preferences.plist` is copied into the container on install / first host-app launch.

**Schema migration:** `displaySettingsMigratedV2` runs only in the host app and removes the deprecated **Preview** column from saved column layouts (file type icons always appear in the **Name** column now).

**Live updates:** When settings change, `SharedPreferencesStore` posts:

- A `NotificationCenter` notification (in-process)
- A Darwin notify event (cross-process, for the extension)

The extension’s `PreviewViewController` observes both and reapplies settings without closing Quick Look. Preference writes are skipped when values are unchanged. Migrations run only in the host app (not during extension reload) to avoid feedback loops.

**App Groups:** Not used — would require a paid Apple Developer provisioning profile. Prefs sync via explicit container path instead.

### Archive loading

| Layer | Responsibility |
|-------|----------------|
| `ArchiveSandboxAccess` | `NSFileCoordinator` reads; in-memory data cache; temp copies in extension container |
| `ZipArchiveReader` | In-process central directory parse; store + deflate extraction |
| `TarArchiveReader` | USTAR parse; gzip in-process; `.tar.xz` via `/usr/bin/xz` on sandbox copy |
| `ExternalArchiveTool` | Bundled `Contents/Resources/7zz`, then Homebrew paths |
| `ArchiveContentLoader` | Format dispatch, tree building, folder metadata aggregation, listing cache |

Archive entries are `FileItem` values with `isArchiveEntry = true` and a `relativePath` inside the archive.

**Listing cache:** Parsed entry lists keyed by archive path + file size + modification time.

**Zip entry cache:** Raw archive bytes cached per path/size/mtime in `ArchiveSandboxAccess`.

External tools (`unzip`, `tar`, `gzip`) remain fallbacks when in-process parsing is insufficient.

### Archive entry open

The Quick Look extension is sandboxed and cannot open staged files in external apps directly.

```
Extension                          Background helper (Dirscope)
─────────                          ────────────────────────────
extract single entry → stage file
write PendingOpen.plist
post Darwin notify  ──────────────► LaunchAgent wakes helper
                                   NSWorkspace.open(staged file)
```

**LaunchAgent:** `com.folderpreview.app.openhelper` — installed by `install-app.sh`, runs `Dirscope -backgroundOpenHelper` at login.

**Staging layout:**

```
~/Library/Containers/com.folderpreview.app.preview/Data/Library/Application Support/Dirscope/
├── Preferences.plist
├── PendingOpen.plist          (written by extension, consumed by helper)
└── OpenStaging/               (extracted files awaiting open)
```

The helper retries pending opens on short delays to avoid races with the extension’s wake request. The main Dirscope window is **not** shown during archive opens.

Status and reinstall: **Behaviors → Archive file opens** in the host app (`ArchiveEntryOpenBridge.backgroundOpenHelperStatus()`).

### Quick Look appearance

The file list, right-hand inspect panel, and footer toolbar share semantic window background via `PreviewTheme.applySurfaceBackground`. Layer fills update in `viewDidChangeEffectiveAppearance` so the inspect pane and footer stay in sync with light/dark mode.

The footer shows path breadcrumb (optional), **item count**, List/Icons switcher, and zoom slider.

### Bundle identifiers

| Component | Identifier |
|-----------|------------|
| Host app | `com.folderpreview.app` |
| Quick Look extension | `com.folderpreview.app.preview` |

User-facing name: **Dirscope** (bundle IDs unchanged from early development).

---

## Key source files

| File | Purpose |
|------|---------|
| `Shared/PreviewSettings.swift` | All setting keys, accessors, and migrations |
| `Shared/SharedPreferencesStore.swift` | Cross-process preference persistence |
| `Shared/ZipArchiveReader.swift` | In-process zip listing and deflate extraction |
| `Shared/TarArchiveReader.swift` | In-process tar/gz listing and extraction |
| `Shared/ArchiveContentLoader.swift` | Archive format dispatch, tree building, entry I/O |
| `Shared/ArchiveEntryOpenBridge.swift` | Staged archive opens from extension to helper |
| `FolderPreviewExtension/PreviewViewController.swift` | Quick Look lifecycle and layout |
| `FolderPreviewExtension/FilePreviewPaneView.swift` | Side-panel previews (folders, archives, images) |
| `FolderPreviewApp/AppVisualKit.swift` | Shared SwiftUI design system |

---

## Development workflow

### Auto rebuild and reinstall

**Option A — Cursor hook:** `.cursor/hooks.json` runs `scripts/rebuild-and-install.sh` after Swift/plist edits. Reload Cursor once if hooks do not pick up immediately.

**Option B — File watcher:**

```bash
./scripts/watch-and-install.sh
```

Both paths debounce changes (~3 seconds), install to `/Applications/Dirscope.app`, reload Quick Look, and log to `DerivedData/install.log`. They call `./install-app.sh --no-open --skip-icons`.

### Manual build

```bash
xattr -cr .
xcodebuild -project FolderPreviewApp.xcodeproj \
  -scheme FolderPreviewApp \
  -derivedDataPath ./DerivedData \
  build

open DerivedData/Build/Products/Debug/Dirscope.app
```

### Regenerating icons

Source artwork: `scripts/icon-source.png`

```bash
./scripts/generate-icons.sh
# or
./scripts/generate-icons.sh /path/to/icon-source.png
```

Produces:

- **AppIcon.appiconset** — opaque icons for Dock, Finder, About
- **AppMark.imageset** — transparent squircle for in-app UI heroes

`install-app.sh` skips icon regen when Pillow is missing or when `--skip-icons` is passed.

---

## Release build

### Ad-hoc (default — no Apple Developer account)

```bash
./scripts/fetch-7zz.sh                    # optional
./scripts/release-build.sh --skip-notarize
```

Writes to `dist/`:

- `Dirscope-VERSION.zip`
- `Dirscope-VERSION.dmg`
- `RELEASE-VERSION.md` (install notes for GitHub)

Both app and extension targets enable **Hardened Runtime** (`ENABLE_HARDENED_RUNTIME = YES`).

### Notarized release (optional — paid Apple Developer Program)

```bash
xcrun notarytool store-credentials dirscope-notary \
  --apple-id "you@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

DEVELOPMENT_TEAM="YOUR_TEAM_ID" NOTARY_PROFILE="dirscope-notary" ./scripts/release-build.sh
```

Environment variables:

| Variable | Purpose |
|----------|---------|
| `DEVELOPMENT_TEAM` | Apple Developer Team ID |
| `NOTARY_PROFILE` | Keychain notarytool profile name |
| `DIRSCOPE_VERSION` | Marketing version (default `1.0.0`) |

The script builds Release, bundles `7zz`, re-signs nested tools, optionally submits to Apple (`notarytool submit` + `stapler staple`), and regenerates zip/dmg.

### Publish to GitHub

```bash
gh release create v1.0.0 dist/Dirscope-1.0.0.zip dist/Dirscope-1.0.0.dmg \
  --title "Dirscope 1.0.0" \
  --notes-file dist/RELEASE-1.0.0.md
```

---

## Troubleshooting (developer)

| Problem | Fix |
|---------|-----|
| Extension crash | `~/Library/Logs/DiagnosticReports/FolderPreviewExtension*.ips` |
| Extension failed during preview | `./install-app.sh`, `killall Finder` |
| Archive open broken | Reinstall LaunchAgent; `pgrep -fl backgroundOpenHelper` |
| Codesign “resource fork… detritus” | `xattr -cr DerivedData` then rebuild |
| Dock shows old icon | `killall Dock` after reinstall |
| Extension not in System Settings | Verify `Dirscope.app/Contents/PlugIns/FolderPreviewExtension.appex` |
| 7z/rar empty in sandbox | Run `./scripts/fetch-7zz.sh` and reinstall |

Inspect preferences:

```bash
plutil -p ~/Library/Containers/com.folderpreview.app.preview/Data/Library/Application\ Support/Dirscope/Preferences.plist
```

---

## Implementation status / known limitations

- **Zip** — listing, nested folders, nested zips, deflate extraction, image/text side-panel preview, per-entry size/modified date (including aggregated folder totals), open in default app via background helper
- **Tar / `.tar.gz` / `.tar.xz`** — in-process listing and extraction with metadata; xz uses `/usr/bin/xz` on sandbox copy before tar parse
- **Single `.gz`** — in-process gunzip
- **`.7z` / `.rar`** — bundled `7zz` in app Resources ([`Vendor/README.md`](../Vendor/README.md)); Homebrew fallbacks for local dev
- **HTML in archives** — Source/Formatted preview with staged temp base URL; complex pages with external assets may need a browser
- **Background helper status** — Behaviors settings shows LaunchAgent installed/running + reinstall action
- **Zip entry cache** — archive bytes and parsed listings cached per path/size/mtime
- **Ad-hoc signing** — used for local and GitHub releases without notarization
- **App Group entitlements** — not used (requires paid signing identity)

**Deferred / out of scope:**

- Syntax highlighting in source preview
- `.zip` inside normal folders as expandable containers (separate feature)
- Full in-process 7z parser (bundled binary is sufficient)

---

## See also

- [README](../README.md) — features, install, fine print, user troubleshooting
- [Vendor/README.md](../Vendor/README.md) — 7-Zip LGPL bundling
