# Bundled third-party tools

## 7-Zip (`7zz`)

Dirscope can bundle the official [7-Zip](https://www.7-zip.org/) command-line binary (`7zz`) so `.7z` and `.rar` archives work in the sandboxed Quick Look extension without Homebrew.

- **License:** 7-Zip is licensed under the GNU LGPL; see the [7-Zip license](https://www.7-zip.org/license.txt).
- **Obtain a copy:** run `./scripts/fetch-7zz.sh` from the repo root, or copy your own `7zz` binary to `Vendor/7zz/7zz`.
- **Install:** `./install-app.sh` copies `Vendor/7zz/7zz` into `Dirscope.app/Contents/Resources/7zz` when present.

The binary itself is gitignored (`Vendor/7zz/`). Do not commit prebuilt binaries unless you have verified licensing and signing requirements for your distribution channel.
