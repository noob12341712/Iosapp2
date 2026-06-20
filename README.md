# macOS Menu Bar Multi-Output Audio Sync

This repository contains a complete, copy-pasteable SwiftUI `MenuBarExtra` app that routes one audio input, such as BlackHole, to multiple checked output devices with per-device manual delay controls from 0 ms to 1000 ms.

## Important macOS audio limitation

macOS does not let a normal sandboxed app capture arbitrary system output audio directly. To route “system audio,” install a virtual audio driver such as BlackHole, set macOS system output to that virtual device, then select that virtual device as this app's input. AirPlay and Bluetooth outputs appear only when macOS exposes them as Core Audio output devices.

## Beginner Xcode steps

1. Install BlackHole 2ch from Existential Audio if you want to capture system audio.
2. Open Xcode and choose **File > New > Project...**.
3. Choose **macOS > App**, then click **Next**.
4. Set **Product Name** to `MenuBarAudioSync`, **Interface** to `SwiftUI`, **Language** to `Swift`, and click **Create**.
5. In the project navigator, open the generated `MenuBarAudioSyncApp.swift` file.
6. Delete all generated code in that file.
7. Copy everything from this repository's `MenuBarAudioSyncApp.swift` and paste it into Xcode.
8. Select the project target, open **Signing & Capabilities**, and make sure **App Sandbox** is disabled for local testing. If you keep sandboxing enabled, add microphone/audio-input entitlement support.
9. Open **Info**, add `Privacy - Microphone Usage Description`, and set it to something like `Routes audio from the selected input to selected speakers.`
10. In macOS **System Settings > Sound > Output**, select `BlackHole 2ch` if you are routing system audio.
11. Run the app from Xcode.
12. Click the speaker icon in the menu bar, choose the input device, check multiple output devices, and adjust each checked device's delay slider between 0 ms and 1000 ms until echo disappears.

## What the code does

- Uses `MenuBarExtra` so the UI lives in the macOS menu bar.
- Scans Core Audio devices for active input and output streams.
- Uses checkboxes to enable multiple output devices at once.
- Builds one input `AVAudioEngine` tap and one output `AVAudioEngine`/`AVAudioPlayerNode` pipeline per checked speaker.
- Schedules each output buffer with a user-controlled host-time offset to create a manual sync delay.

## Production notes

This is starter code intended for local experimentation. For production use, add drift correction, persistent settings, better underrun handling, device-change listeners, and a hardened virtual-driver workflow.
