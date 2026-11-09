# Lifebook

Caregiver handoff for one kid, one day at a time. Native SwiftUI (iOS 17+), built from the **Lifebook App Pearl** design.

No accounts, no server. Each phone keeps its own copy of the log. Handoffs move as a `.lifebook` file (human-readable JSON) by **AirDrop**, or by **Messages** in a pinch. Opening the file merges it into the phone's log.

## How the spec maps to no-server

| Spec | Here |
| --- | --- |
| Dad signs in with email, invites by link | Parent sets up kid + ≤3 points + their own name, then AirDrops/texts the file. Anyone who opens it types their name and is in — no team list to maintain. Their name reaches the other phones inside their own handoff files. |
| Normal / Abnormal + note | "All good" / "Concern"; a concern needs a note before handoff. |
| Next caregiver sees all notes for the day | Handoff file carries the whole day (last 7 days); merge is by session id, so re-sending is harmless. |
| Next caregiver blocked until previous session has notes | A caregiver can't start until today's notes have reached their phone (or while someone's session is known to be open). They can nudge (share sheet), open the file, or start anyway; starting anyway is recorded for the parents. Parents are never blocked. |
| Previous caregiver gets notifications to add notes | Local notifications on the current caregiver's own phone: 15 min before end, at end, then every 15 min for an hour until the handoff file is actually shared. |
| Open: session length / who's next | 2/4/6/8 h (changeable mid-shift). No "who's next" picker: whoever you AirDrop or text the file to is next. |
| EOD to Mom & Dad | Send the last file of the day to a parent; parents start each day. |

Not possible without a server: alerting a caregiver who *forgot to start* their session (their phone doesn't know they're on).

## Build & test

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Lifebook.xcodeproj -scheme Lifebook -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`LifebookTests` covers rules, merge and file exchange; `LifebookUITests` taps through Switch person, joining by name, and a full shift.

Debug-only launch arguments for screenshots/QA: `-resetState`, `-demo "Deb K."` (or `"Priya"`, `"Deb K.:first"` for the blocked case), `-route blocked|join|setup|log|logConcern|logDone|handoff|digest|team|points`, `-meName <name>`, `-exportTo <path>`, `-importPath <path>`.

Code: `Lifebook/Sources/Rules.swift` (gating, flags, merge), `Store.swift` (state, file exchange), `Reminders.swift`, `Views/`.

## TestFlight

Bundle ID: `app.lifebook.Lifebook`. Signing team: Immortal Company (`3UGCLFLDJ6`).
Sign into that team's Apple Account in Xcode Settings before archiving or uploading.

App Store Connect: **Lifebook: Care Team** (Apple ID `6832359351`).
[Manage TestFlight](https://appstoreconnect.apple.com/teams/f2a8bd72-1d69-4ac9-81ab-2b4230869627/apps/6832359351/testflight).
The iPhone display name remains **Lifebook**.
External testing uses the **Caregivers** group with email invitations. Each build
must be approved for external TestFlight testing before caregivers can install it.

For each new upload, increase `CURRENT_PROJECT_VERSION` in `project.yml`, then run:

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Lifebook.xcodeproj -scheme Lifebook -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Lifebook.xcarchive \
  -allowProvisioningUpdates archive
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -exportArchive -archivePath build/Lifebook.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/TestFlight \
  -allowProvisioningUpdates
```

The export command uploads the build to App Store Connect. After Apple processes it,
assign it to a TestFlight group. External testing also requires TestFlight App Review.
