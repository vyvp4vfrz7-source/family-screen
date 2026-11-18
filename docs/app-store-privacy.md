# App Store Connect answers

## App Privacy ("nutrition label")
Data collected **by the developer**: **None**. Choose "No, we do not collect data from this app".

Why that is true: photos, notes and messages go to the user's own iCloud (CloudKit private/shared database), which the developer cannot read; Apple treats this as not collected by the developer. There are no analytics, ads, accounts or servers.

## Other questions
- Uses encryption: only Apple's standard HTTPS → `ITSAppUsesNonExemptEncryption = NO` (already in Info.plist).
- Age rating: 4+. "Unrestricted web access": No (headlines open only the linked article from feeds the family chose).
- User-generated content: yes, inside invite-only families. Moderation: hide a home, report (email), owner removes members, delete content.
- Privacy policy URL: where you host `docs/privacy.html` (also set `PRIVACY_URL` in `Config/Signing.xcconfig`).
- Support URL / email: set `SUPPORT_EMAIL` in `Config/Signing.xcconfig`.

## Review notes (paste into "Notes for reviewer")
Family Screen is a wall display for a family split between two homes. To see sync, the reviewer needs two iCloud accounts: on iPad A open Settings (gear) ▸ Send invite link, open the link on iPad B. Without a second iPad, all screens work on one iPad: add a photo with +, type on the message board, swipe pages.
