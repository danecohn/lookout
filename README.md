<p align="center"><img src="assets/Lookout.png" width="128" alt="Vigil Lookout icon"></p>

# Vigil Lookout

A native macOS WebKit browser by **VigilTech** (vigiltech.org), founded by **Demetria Althea Cohn**. Original application source; the system WebKit framework supplies the engine. macOS 14+, Apple silicon and Intel.

- Vertical tabs, pinned pages, named spaces, and a cross-space tab finder (⌘K).
- **Focus trails**: related opener tabs stay together; focus one connected trail without losing other pages.
- **Reference pane**: keep one page beside the main page while continuing your research.
- **Saved trails**: save related source links with a purpose, resume in a new space, or export readable Markdown for Mind or Prompter. No page scraping or AI account required.
- **Vigil Search** is the default at the existing search route while its domain is chosen. Switch to Kagi, DuckDuckGo, or Google in Settings. Kagi may require your own account; no subscription is bundled.
- Real WebKit navigation, gesture history, downloads with save dialogs, find, print/PDF, zoom, JavaScript dialogs, and file upload dialogs.
- Regular windows restore tabs lazily. Private windows use an isolated temporary website store and save no history, tabs, or trails. Downloads still create files you choose.
- Native translucent sidebar and original illustrated telescope icon with the VigilTech product icon style.

## Build and test

Use Xcode/Swift 5.9 or later on macOS. `swift test` tests core behavior. `bash scripts/package-macos.sh arm64` or `x86_64` produces an ad-hoc signed `.app`, verified DMG, and SHA256 checksum. CI tests and packages both native architectures before publishing. No Apple signing secrets are required for ad-hoc builds. They are **not Developer ID signed or notarized**; macOS may require you to approve opening them in Privacy & Security. Do not disable Gatekeeper globally.

For native engine QA, run `python3 scripts/fixture.py 4397`, then the built executable with `--self-test --fixture-origin http://127.0.0.1:4397`. This uses temporary website stores, not your regular data.

## Privacy, security, and limits

No analytics, AI service, account requirement, or cloud sync is added. Search queries go to the search engine you choose; websites receive normal browser requests. Regular browsing state is stored locally at `~/Library/Application Support/Artemis Lookout/session.json` with owner-only permissions. Authentication-token URLs are excluded from persistent sessions/history/trails. A damaged/newer session is preserved and saving is disabled until you move that file aside. Website cookies are managed separately by system WebKit.

TLS uses the default system trust evaluation; there is no invalid-certificate bypass. The address bar rejects scripts/data/file URLs and embedded credentials. External mail/tel links require a confirmation. Downloads never auto-execute. An unsaved-form guard detects input in the main frame; it is best effort and cannot detect every custom editor/iframe or recover typed contents. There is no content blocker, Safari-extension support, Safari history/password import, iCloud Keychain integration, sync, or claim of full Safari feature parity in v0.1.

This is a new, macOS-focused product. Existing Venture releases remain separate; Lookout does not mislabel those Windows/Linux builds as WebKit releases.

[GPL-3.0-only](LICENSE) · [Third-party notices](NOTICE.md) · [Vigil Search source and attribution](https://github.com/danecohn/Artemisearch)

Vigil Lookout 0.1.2 retains the existing bundle identifier, legacy session path,
search-provider preference values and installer filenames for upgrade compatibility.
The interface uses the VigilTech design tokens (`Sources/Lookout/Theme.swift`) and Vigil Sans; brand files are in `assets/vigiltech`.

A product of VigilTech, vigiltech.org.
