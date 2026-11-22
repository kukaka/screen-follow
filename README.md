# ScreenFollow

ScreenFollow is a lightweight macOS menu bar utility for switching a two-monitor setup between one active desktop and an extended desktop. It is useful when an HDMI monitor remains connected in macOS after you turn it off and the pointer can still move onto the dark screen.

## Requirements

- Apple silicon Mac running macOS 13 Ventura or later
- Two displays, with the Dell Display configured as the secondary display

The current version targets the Dell Display by its display identifier.

## Use ScreenFollow

Unzip the application archive and open `ScreenFollow.app`. Click the overlapping-display icon in the menu bar.

- **Switch to Single Desktop** mirrors the main display to the Dell. HDMI stays connected, and there is one active desktop.
- **Restore Extended Desktop** returns to two independent desktops.
- **Quit ScreenFollow** exits the app and releases its temporary display configuration.

Switching is manual. ScreenFollow checks the display layout when you open the menu or choose an action. It has no polling timer, login item, or background helper.

## Build from source

With Apple's Command Line Tools installed, run from the project root:

```sh
./build.sh
open build/ScreenFollow.app
```

The build uses AppKit and Core Graphics, bundles the Finder icon, and applies an ad hoc signature. The packaged app is not notarized.

To create a ZIP of the built app:

```sh
ditto -c -k --keepParent build/ScreenFollow.app build/ScreenFollow.zip
```

## Regenerate the app icon

`Resources/AppIcon.icns` is included in the project. If you modify `Resources/DrawIcon.swift`, regenerate the icon before rebuilding:

```sh
mkdir -p build
swift -module-cache-path "$PWD/build/module-cache" Resources/DrawIcon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
./build.sh
```
