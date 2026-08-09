# Watch Voice Intake

Minimal Apple Watch app: press to record, press to stop, the recording
reaches [Research OS](https://researchos.shuyinlab.com)'s AI Intake pipeline
and comes out the other end as an organized note. The Watch does exactly one
thing — capture and reliably hand off raw audio. All transcription/AI
organizing happens server-side, reusing Research OS's existing pipeline.

Full feasibility research, architecture decision, and phased plan:
see the design doc from the planning session (not included in this repo —
lives in the Research OS project's session history). Short version below.

## Architecture

```
Watch (record, AVAudioRecorder)
  → WatchConnectivity.transferFile (OS-managed, survives app kill)
  → iPhone companion app
  → local pending-upload queue
  → HTTPS POST to Research OS (Idempotency-Key: recording UUID)
  → server: transcribe (reuses existing /api/ai/transcribe logic)
  → server: AI-organize (reuses existing AI Intake logic)
  → staged in a pending table (never writes directly into the note store —
    same safety pattern Research OS already uses for meeting/evolver drafts)
  → Research OS client pulls + merges on next open
```

Chose **Watch → iPhone relay**, not Watch → server direct, because
standalone Watch networking and background-upload timing are both
documented as unreliable (see Apple Developer Forum threads referenced in
the design doc) — the relay avoids betting the whole feature on an area
Apple's own community hasn't fully solved yet.

## Project setup

This project is defined with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`project.yml`) — the `.xcodeproj` itself is generated, not committed, so
there's nothing to merge-conflict on.

```bash
brew install xcodegen
xcodegen generate
open WatchVoiceIntake.xcodeproj
```

CI (`.github/workflows/build.yml`) does the same on every push — this repo
is public specifically so GitHub's macOS runner minutes are free and
unlimited for compiling. No Apple Developer account, no signing, no cost.

## Status

**Phase 1** — minimal project structure + unsigned cloud compile. This is
where the project currently is: it should build, nothing has been tested on
real hardware yet.

| Phase | Goal | Status |
|---|---|---|
| 0 | Architecture decided (Watch → iPhone relay) | ✅ |
| 1 | Project compiles via GitHub Actions | ✅ (verify: check the Actions tab) |
| 2 | Local recording works on-device | ⬜ needs real Watch |
| 3 | WatchConnectivity transfer verified | ⬜ needs real Watch + iPhone |
| 4 | Server-side `/api/watch/voice` + AI Intake integration | ⬜ not started |
| 5 | Full real-device end-to-end test | ⬜ needs a Mac to install a dev build |
| 6 | Reliability hardening (retry, offline queue, dedup) | ⬜ not started |

## What's intentionally NOT here yet

No login screen, no recordings list/playback, no AI chat, no on-Watch
transcription, no settings screen, no CloudKit/iCloud. First version is
record → upload → done, full stop.
