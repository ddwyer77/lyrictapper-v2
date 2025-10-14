## Lyric Tapper (SwiftUI, macOS, MAS-compliant)

This is the SwiftUI scaffolding for a Mac App Store–compliant rebuild of Lyric Tapper.

### What’s here
- Swift source files for models, services, and views
- MAS entitlements templates

### Getting started (create Xcode project)
1. Open Xcode and create a new project: App > macOS > App (SwiftUI, Swift).
2. Name it "LyricTapper" and set the location to this folder.
3. In the Project Navigator, drag the `LyricTapper` folder (containing Sources) into the project, choosing "Create folder references" or "Create groups" as you prefer.
4. Set the app target to macOS 13.0 or newer.
5. In Signing & Capabilities:
   - Add "App Sandbox"
   - Enable "User Selected File — Read/Write"
   - Optionally enable "Network — Client" if needed
   - Use the provided `LyricTapper.mas-dev.entitlements` during development; switch to `LyricTapper.mas.entitlements` for submission.

### Targets
- mas-dev: for local testing with your App Store signing (development provisioning)
- mas: for App Store submission

### Build & Run
- Use a short local audio file for early testing.
- The initial app scaffolding includes placeholders for audio, waveform, tapping, editing, and export.

### Export (MAS-compliant)
- Export is implemented via AVFoundation (no ffmpeg). The scaffold provides the structure; fill in `ExportService` to render the MP4 using `AVAssetWriter`, `AVMutableComposition`, and `AVVideoComposition`.

### Entitlements
- See `LyricTapper.mas-dev.entitlements` and `LyricTapper.mas.entitlements` in the repository. Attach the appropriate entitlements file to each target.

### Notes
- Security-scoped bookmarks are used to persist access to user-chosen audio files.
- Waveform generation is scaffolded to use `AVAssetReader` + Accelerate/vDSP.
- Timing computation matches the existing Electron logic.

## Image Flash

Create a hard-cut 9:16 video where each tap advances to a new random image from a selected folder.

Steps:
1. Open the app to the Home screen and choose "Image Flash".
2. Load an audio file (Choose Audio…).
3. Choose an image folder. Optionally enable "Include subfolders" and "Skip duplicate images".
4. Tap view: Press Space while audio plays to advance images. Use R to "Restart Take (R)". Press Enter to proceed.
5. Edit intervals as needed (swap, delete, nudge). Then go to Export to Render Preview or Export Video. Use "Reshuffle Images" to change the image order deterministically.

Output is locked to 1080×1920 @ 30fps, images scaled to full width on a black background with hard cuts, and original audio muxed.


