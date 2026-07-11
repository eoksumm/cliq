# Cliq

A menu bar app for macOS that plays a click sound whenever you click your mouse or trackpad, anywhere on the system. Press and release each have their own sound, like a mechanical switch.

## Install

Download the latest `.dmg` from the [Releases](https://github.com/eoksumm/cliq/releases) page, open it, and drag Cliq into Applications.

The app isn't signed with an Apple Developer certificate, so macOS will block it the first time you open it. To allow it:

1. Try to open Cliq (you'll get a warning).
2. Go to System Settings > Privacy & Security, scroll down, and click "Open Anyway" next to the Cliq message.

Cliq runs from the menu bar only, there's no dock icon or window.

## Usage

Click the Cliq icon in the menu bar to open the menu:

- **Enabled** - turn click sounds on/off without quitting
- **Volume** - slider to adjust loudness
- **Click Sound** - pick between three sound packs
- **Start at Login** - launch Cliq automatically when you log in
- **Quit**

## Build from source

Requires Xcode command line tools (macOS 13+).

```
git clone https://github.com/eoksumm/cliq.git
cd cliq
./build.sh
./install.sh
```

`build.sh` compiles the app and produces `Cliq.app`. `install.sh` copies it to `/Applications` and launches it.

## Requirements

macOS 13 (Ventura) or later.
