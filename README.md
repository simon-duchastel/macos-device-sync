# MacOsDeviceSync

A macOS menu bar app that automatically connects your Bluetooth trackpad when a specific Bluetooth keyboard is connected. 

## Requirements

- macOS 12.0+
- blueutil (`brew install blueutil`)

## Build

```bash
./build.sh
open build/MacOsDeviceSync.app
```

## Setup

Launch the app and it will begin running in your menu bar. Select "Preferences" and input the MAC address of your bluetooth keyboard and your bluetooth trackpad/mouse (you can find these by running `blueutil --paired` while both are connected via bluetooth).

The app will poll the bluetooth status once every 2 seconds and auto-connect your trackpad if you keyboard becomes connected.
