# PocketLaunch

Personal native iPhone launcher, independent of NX2Apple's shell and LiveContainer.

Implemented: persistent game library, search, favorites, custom launch links, local IPA import, file sharing, SideStore installation links, custom cover art, and a cartridge launch animation using each game's artwork. Long-press a game to favorite or remove it. Swipe an IPA to delete the local copy.

## Build from Windows

Upload the contents of this PocketLaunch folder as the root of your own GitHub repository, including the hidden .github folder. Run Actions → Build iPhone IPA → Run workflow. Download the PocketLaunch-unsigned artifact, unzip it, and import PocketLaunch.ipa into SideStore. The workflow runs on Apple's build tools on a GitHub macOS runner. GitHub Actions usage can incur charges depending on your account and repository.

On a Mac, install Xcode and XcodeGen, run `xcodegen generate`, then open the generated project. The workflow contains the unsigned IPA packaging commands.

## Game launching

Games remain separately installed. A game must register a URL scheme to be opened by this launcher. No verified launch scheme is currently supplied for your Pokopia or South Park builds. The inspected NX2Apple frontend did not expose a documented per-game launch-link contract. Its engine and your specific IPA Info.plist files still need inspection. If a game has no scheme, adding a unique CFBundleURLTypes registration to that game's IPA before re-signing is a possible next step to test. A bundle ID by itself is insufficient. Do not overwrite working installations or saves during this investigation.

This app does not execute IPA archives in its own process. A local IPA is shared via the iOS share sheet; availability of SideStore as a destination needs device testing. For hosted files, it uses SideStore's documented `sidestore://install?url=...` URL with an encoded HTTPS address.

## Validation status

Source and build configuration created on Windows. No Xcode build, simulator run, IPA signing, or on-device test has been performed. Launch behavior, large IPA imports, and SideStore local-file handoff require device validation. Do not treat this as a compiled or tested release.

## Read artwork from an IPA

For a game already in your library, long-press its card, choose Change artwork → Use icon from IPA, select the original IPA in Files, then Save. This reads just its icon and does not copy the entire IPA into the library. Its cartridge animation uses the same artwork.

Importing an IPA through the IPAs tab also reads its icon and fills empty artwork for existing games matched by registered URL scheme or SideStore/AltStore bundle identifier. Existing custom artwork is preserved. Launch links still need to refer to your installed, signed game.

The reader supports binary and XML plists, primary icon declarations, legacy icon keys, and common loose PNG icon names. Asset-catalog-only icons and unreadable PNGs fall back to selecting artwork from Photos. It does not inspect other installed apps' private files.

The metadata reader is tested with synthetic IPA archives by `swift test` in the build workflow. Actual IPA icon decoding and the iPhone UI still require device validation.

Archive reading uses [ZIPFoundation 0.9.20](https://github.com/weichsel/ZIPFoundation/tree/0.9.20), under its MIT license.
