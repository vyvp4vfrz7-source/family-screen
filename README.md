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
5. Run on the first home's iPad, open Settings (gear) ▸ **Send invite link**, and send it by Messages, WhatsApp or email.
6. The other home installs the app, signs in to iCloud, and taps the link once. Both screens now share photos and messages; new items pop up within 30 seconds.
7. Once everyone has joined you can switch the link off. Settings also lists family members (remove one), and has Leave / Delete family.

### Sending photos from an iPhone (Share ▸ Family Screen)

The app also runs on iPhone as the "sender", with a Share Extension so photos can be sent from Photos, WhatsApp and other apps.

1. In Signing & Capabilities, pick your team for **both** targets: `FamilyScreen` and `ShareExtension` (bundle ID = app ID + `.share`).
2. Both targets need the **App Groups** capability with `group.<your bundle id>` and the same iCloud container `iCloud.<your bundle id>`. The entitlements files already list them; if Xcode shows a red error, press **+** to register the group / tick the container.
3. Run on the iPhone once, sign in to iCloud and tap the family's invite link (or be the person who made the family with the same Apple ID). After that, Share ▸ Family Screen sends straight to the family. If it can't send yet, the photo waits and the app sends it next time it opens.

### Photos: limits, shared albums and frames

- Every shared copy is at most 2048 px and re-encoded, so location and other EXIF data are removed.
- A family keeps up to 300 photos; unpinned photos are removed after 90 days. Press and hold a photo ▸ **Keep** to pin it.
- Settings ▸ Photos ▸ **iCloud Shared Album** shows an album this iPad already follows, next to the family photos (asks for Photos access; nothing is uploaded).
- Settings ▸ Photos: frame (polaroid with the note, white mat, gold Chinese), slow pan and zoom, festival themes (Christmas, Lunar New Year, and "birthday" events in today's calendar).

Before the App Store: set `SUPPORT_EMAIL` and `PRIVACY_URL` in `Config/Signing.xcconfig`. The policy text is `docs/privacy.html`; App Store Connect answers are in `docs/app-store-privacy.md`.

Each family's data stays in their own iCloud. There is no server and no shared key.

## What's where

| File | What it does |
| --- | --- |
| `FamilyScreen/DashboardView.swift` | The main screen, refresh loop, night mode, hourly chime |
| `FamilyScreen/Panels.swift` | Photo slideshow, city cards, message board, calendar, FaceTime orb, news, pop-up |
| `FamilyScreen/SettingsView.swift` | Settings and the invite button |
| `FamilyScreen/FamilyStore.swift` | Photos and messages on the iPad, outbox, 300/90-day limits |
| `Shared/FamilyModels.swift` | Photo/message types, app group, outbox, clean 2048 px copies (shared with the extension) |
| `ShareExtension/ShareViewController.swift` | Share ▸ Family Screen |
| `FamilyScreen/SharedAlbum.swift` | iCloud Shared Album source and Settings picker |
| `FamilyScreen/PhotoFrames.swift` | Frames, pan and zoom, festival themes, setup card |
| `FamilyScreen/PhoneHomeView.swift` | iPhone screen |
| `Shared/CloudSync.swift` | CloudKit sync and sharing between homes |
| `FamilyScreen/Weather.swift` | WeatherKit (iPadOS 16+) or Open-Meteo |
| `Shared/L10n.swift` | All words in every language |

Every push is compiled on GitHub's Mac runners (Actions ▸ Build) to catch errors before you open Xcode.
