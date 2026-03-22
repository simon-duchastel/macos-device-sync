# MacOsDeviceSync

A macOS menu bar app that automatically connects your Bluetooth trackpad when a specific Bluetooth keyboard is connected.

## Requirements

- macOS 12.0+

## Build

```bash
./build.sh
open build/MacOsDeviceSync.app
```

## Setup

Launch the app and it will begin running in your menu bar. Select "Preferences" and input the MAC address of your Bluetooth keyboard and your Bluetooth trackpad/mouse.

**Finding your device MAC addresses:**
1. Click "Show Paired Devices" in the Preferences window
2. Find your keyboard and trackpad in the list
3. Copy the MAC addresses (format: XX-XX-XX-XX-XX-XX)

The app will poll the Bluetooth status once every 2 seconds and auto-connect your trackpad if your keyboard becomes connected.
