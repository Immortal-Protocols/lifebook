# Lifebook

Caregiver handoff for one kid, one day at a time. Native SwiftUI (iOS 17+), built from the **Lifebook App Pearl** design.

No accounts, no server. Each phone keeps its own copy of the log. Handoffs move as a `.lifebook` file (human-readable JSON) by **AirDrop**, or by **Messages** in a pinch. Opening the file merges it into the phone's log.

## How the spec maps to no-server

| Spec | Here |
| --- | --- |
| Dad signs in with email, invites by link | Parent sets up kid + ≤3 points + team, then AirDrops/texts the family file. Opening it sets up the caregiver's phone; they pick who they are. |
| Normal / Abnormal + note | "All good" / "Concern"; a concern needs a note before handoff. |
| Next caregiver sees all notes for the day | Handoff file carries the whole day (last 7 days); merge is by session id, so re-sending is harmless. |
| Next caregiver blocked until previous session has notes | If the last known handoff went to someone else, you're blocked until their file arrives. You can nudge them (share sheet), open the file, or start anyway; starting anyway is recorded for the parents. Parents are never blocked. |
| Previous caregiver gets notifications to add notes | Local notifications on the current caregiver's own phone: 15 min before end, at end, then every 15 min for an hour until the handoff file is actually shared. |
| Open: session length / who's next | 2/4/6/8 h (changeable mid-shift); the caregiver picks who's next at start and can change at handoff. |
| EOD to Mom & Dad | Caregivers default to handing off to a parent; parents start each day. |

Not possible without a server: alerting a caregiver who *forgot to start* their session (their phone doesn't know they're on).

## Build & test

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Lifebook.xcodeproj -scheme Lifebook -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Debug-only launch arguments for screenshots/QA: `-resetState`, `-demo "Deb K."` (or `"Priya"`, `"Deb K.:first"` for the blocked case), `-route blocked|setup|log|logConcern|logDone|handoff|digest|team|points`, `-meName <name>`, `-exportTo <path>`, `-importPath <path>`.

Code: `Lifebook/Sources/Rules.swift` (gating, flags, merge), `Store.swift` (state, file exchange), `Reminders.swift`, `Views/`.
