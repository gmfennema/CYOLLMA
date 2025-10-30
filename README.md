# CYOLLMA

CYOLLMA is a macOS SwiftUI app for running choose‑your‑own‑adventure sessions against local Ollama models or Groq's hosted LLMs. It guides the model with strict prompts to keep chapters fresh, collects player choices, and lets you steer the story with write‑ins or explicit creative direction.

## Demo

<p align="center">
  <img src="assets/CYOLLMA.gif" alt="CYOLLMA Demo" width="600" style="border-radius:10px;box-shadow:0 6px 18px rgba(0,0,0,0.18);">
</p>

## Download

<p align="center">
  <a href="https://github.com/gmfennema/CYOLLMA/raw/main/CYOLLMA-app.dmg" download>
    <img src="https://img.shields.io/badge/Download-CYOLLMA.app-blue?style=for-the-badge&logo=apple&logoColor=white" alt="Download for Apple Silicon">
  </a>
</p>

**For Apple Silicon (M1/M2/M3) Macs**

**Installation:**

1. Download the DMG file above (it will be in your Downloads folder)
2. **If macOS shows "CYOLLMA is damaged and can't be opened"** when trying to open the DMG, run this command in Terminal to remove the quarantine attribute:
   ```bash
   xattr -d com.apple.quarantine ~/Downloads/CYOLLMA-app.dmg
   ```
   Then try opening the DMG again.
3. Open the DMG and drag `CYOLLMA.app` to your Applications folder
4. If macOS shows "CYOLLMA.app is damaged and can't be opened" when launching the app, run:
   ```bash
   xattr -d com.apple.quarantine /Applications/CYOLLMA.app
   ```
5. Right-click the app and select "Open" the first time you launch it, then click "Open" again when prompted

## Features

- **Model switching** – Flip between local Ollama models and Groq’s cloud models from the in‑app settings modal.
- **Chapter management** – Tracks the active playthrough, supports regenerating chapters or just refreshing the choice list.
- **Creative direction** – Queue bespoke guidance that’s woven into the next generated chapter.
- **Narration (Groq)** – Generate text‑to‑speech narration for any chapter using Groq’s `playai-tts`, with playback speed control.

## Getting Started

1. Install dependencies:
   - Ollama with at least one compatible model installed if you want to run locally.
   - A Groq API key if you plan to use Groq models or narration.
2. Open `CYOLLMA.xcodeproj` in Xcode 15 or newer.
3. Build and run the `CYOLLMA` scheme.
4. From the home screen, open **Settings** to select your provider and model, then pick or author a starting scenario.

## Screenshots

<p align="center">
  <table>
    <tr>
      <td align="center">
        <img src="assets/homescreen.png" alt="Home screen" width="400" style="border-radius:10px;box-shadow:0 6px 18px rgba(0,0,0,0.18);margin:12px;">
      </td>
      <td align="center">
        <img src="assets/settings.png" alt="Settings" width="400" style="border-radius:10px;box-shadow:0 6px 18px rgba(0,0,0,0.18);margin:12px;">
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="assets/local_or_cloud.png" alt="Settings provider picker" width="400" style="border-radius:10px;box-shadow:0 6px 18px rgba(0,0,0,0.18);margin:12px;">
      </td>
      <td align="center">
        <img src="assets/story_view.png" alt="Story view with narration controls" width="400" style="border-radius:10px;box-shadow:0 6px 18px rgba(0,0,0,0.18);margin:12px;">
      </td>
    </tr>
  </table>
</p>

## License

This project is provided as‑is; add licensing details here if you plan to distribute it.
