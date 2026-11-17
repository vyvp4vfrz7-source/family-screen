# Family Screen

Turns an iPad (iPadOS 15 or later) into a family screen for two homes: photos with notes, a message board (留言板) with a "❤️ 收到" reply, clocks and weather for two cities, the next week's calendar, a one-tap FaceTime button, a night clock, and spoken time and messages in English, Cantonese, Mandarin, Hindi or Polish. News is a reader: the family adds their own RSS feeds and the app shows only the headline, the source and a link.

## Build and run on your iPad (free Apple ID)

1. Install **Xcode** from the Mac App Store and open it once so it finishes installing.
2. Download this repo: in Terminal, `git clone https://github.com/vyvp4vfrz7-source/family-screen.git` (or use GitHub Desktop).
3. Open `Config/Signing.xcconfig` in any text editor and change `com.example.familyscreen` to something unique, e.g. `com.billy.familyscreen`.
4. Double-click `FamilyScreen.xcodeproj`.
5. Xcode ▸ Settings ▸ Accounts ▸ **+** ▸ Apple ID, and sign in.
6. Click the **FamilyScreen** project in the left sidebar ▸ target **FamilyScreen** ▸ **Signing & Capabilities** ▸ Team: pick your name (Personal Team).
7. Plug the iPad into the Mac with a cable, unlock it and tap **Trust**. On iPadOS 16+, also turn on Settings ▸ Privacy & Security ▸ **Developer Mode** and restart the iPad.
8. At the top of Xcode, pick your iPad as the run destination and press **▶ Run** (⌘R).
9. The first time, the iPad says "Untrusted Developer": go to Settings ▸ General ▸ VPN & Device Management ▸ your Apple ID ▸ **Trust**, then press Run again.

With a free Apple ID the app works on one iPad on its own and must be re-run from Xcode every 7 days. Weather comes from Open-Meteo.

## Linking two homes (paid Apple Developer account, £79/year)

1. Join the Apple Developer Program and pick that team in step 6 above.
2. In `Config/Signing.xcconfig` set `APPLE_SERVICES = YES`.
3. In Signing & Capabilities, Xcode adds **iCloud (CloudKit)** with container `iCloud.<your bundle id>`. If it shows a red error, tick the container or press **+** to create it.
4. At developer.apple.com ▸ Certificates, IDs & Profiles ▸ Identifiers ▸ your app ▸ tick **WeatherKit** (both the Capabilities and App Services tabs) and save.
5. Run on the first home's iPad, open Settings (gear) ▸ **Invite the other home**, and send the link (Messages or email) to someone in the other home.
6. They install the app on their iPad (same build), sign in to iCloud, and tap the link. Both screens now share photos and messages; new items pop up within 30 seconds.

Each family's data stays in their own iCloud. There is no server and no shared key.

## What's where

| File | What it does |
| --- | --- |
| `FamilyScreen/DashboardView.swift` | The main screen, refresh loop, night mode, hourly chime |
| `FamilyScreen/Panels.swift` | Photo slideshow, city cards, message board, calendar, FaceTime orb, news, pop-up |
| `FamilyScreen/SettingsView.swift` | Settings and the invite button |
| `FamilyScreen/FamilyStore.swift` | Photos and messages on the iPad |
| `FamilyScreen/CloudSync.swift` | CloudKit sync and sharing between homes |
| `FamilyScreen/Weather.swift` | WeatherKit (iPadOS 16+) or Open-Meteo |
| `FamilyScreen/L10n.swift` | All words in every language |

Every push is compiled on GitHub's Mac runners (Actions ▸ Build) to catch errors before you open Xcode.
