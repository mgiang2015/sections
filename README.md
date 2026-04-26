# sections

A local-first iOS app for dance instructors to mark, name, and replay specific segments of an audio track — with speed control, loop mode, and full offline support.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Architecture](#architecture)
- [Data Model](#data-model)
- [Key Design Decisions](#key-design-decisions)
- [Known Limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Contact](#contact)

---

## Overview

sections lets users import MP3, WAV, or M4A audio files, define named time-range sections (start + end timestamp), and play those sections with precise controls. All data is stored locally on-device — no accounts, no cloud, no internet required.

**Target users:** Dance instructors who need to drill specific parts of a track during class without fumbling with a standard music player.

---

## Features

- Import MP3, WAV, and M4A files from the iOS Files app
- Create, edit, and delete named sections with start/end timestamps
- Mark timestamps manually (mm:ss input) or live while audio plays
- Loop a section continuously or play it once
- Adjust playback speed from 0.5× to 2× with pitch preservation
- Skip forward/backward 5 seconds within a section
- Sort audio library by most recently added or alphabetically
- Export section metadata as JSON per audio file (via share sheet)
- Import and merge JSON section data back into the app
- Background audio — playback continues when the app is backgrounded
- Handles interruptions gracefully (phone calls, Siri, alarms)
- Fully offline — no network requests of any kind

---

## Tech Stack

| Concern | Choice |
|---------|--------|
| Language | Swift |
| UI | SwiftUI |
| Local storage | SwiftData |
| Audio engine | AVFoundation |
| Minimum iOS | 17.0 |
| Distribution | App Store |
| Dependencies | None — Apple frameworks only |

---

## Project Structure

```
sections/
├── App/
│   └── SectionsApp.swift              # @main entry point, audio session activation
├── Models/
│   ├── AudioFile.swift                # SwiftData model — imported audio files
│   ├── AudioSection.swift             # SwiftData model — time-range sections
│   ├── SectionExport.swift            # Codable DTOs for JSON export/import
│   └── LibrarySortOrder.swift         # Enum — sort options for audio library
├── Views/
│   ├── Library/
│   │   ├── AudioLibraryView.swift     # Home screen — audio file list
│   │   └── AudioFileRowView.swift     # Single row in the library list
│   ├── sections/
│   │   ├── SectionsListView.swift     # Per-file sections list
│   │   ├── SectionRowView.swift       # Single row in the sections list
│   │   ├── SectionFormView.swift      # Create / edit section sheet
│   │   └── LiveMarkingView.swift      # Live tap-to-mark timestamps sheet
│   ├── Playback/
│   │   └── PlaybackControlsView.swift # Inline playback bar
│   └── Components/
│       └── ShareSheet.swift           # UIActivityViewController wrapper
├── ViewModels/
│   ├── AudioLibraryViewModel.swift    # File import + delete logic
│   ├── PlaybackViewModel.swift        # AVFoundation playback state machine
│   ├── ExportImportViewModel.swift    # JSON export + import + merge logic
│   └── LiveMarkingViewModel.swift     # Live marking step state machine
├── Services/
│   ├── AudioFileService.swift         # AVFoundation helpers (audio duration)
│   └── AudioSessionManager.swift      # AVAudioSession configuration
└── Utilities/
    └── TimeFormatter.swift            # mm:ss ↔ TimeInterval conversion

SectionsTests/
├── TimeFormatterTests.swift
├── PlaybackModeTests.swift
├── AudioSectionTests.swift
├── AudioFileTests.swift
├── SectionExportTests.swift
├── AudioLibraryViewModelTests.swift
├── ExportImportViewModelTests.swift
├── PlaybackViewModelTests.swift
└── LiveMarkingViewModelTests.swift
```

---

## Getting Started

### Prerequisites

- **Xcode 15+** (download from the Mac App Store)
- **macOS Ventura 13.5+**
- **Apple Developer account** ($99/year) — required for running on a real device and App Store distribution. Sign up at [developer.apple.com](https://developer.apple.com)
- A **physical iPhone running iOS 17+** is strongly recommended for testing — AVFoundation audio and the Files app document picker behave differently in the Simulator

### 1. Clone the repository

```bash
git clone https://github.com/mgiang2015/sections.git
cd sections
```

### 2. Open in Xcode

```bash
open sections.xcodeproj
```

### 3. Configure signing

1. In Xcode, select the **sections** project in the file navigator
2. Select the **sections** target
3. Open the **Signing & Capabilities** tab
4. Under **Team**, select your Apple Developer account
5. Update the **Bundle Identifier** if needed (e.g. `com.yourname.sections`)

### 4. Add Background Audio capability

This is required for audio to continue playing when the app is backgrounded:

1. Still in **Signing & Capabilities**, click **+ Capability**
2. Search for **Background Modes** and add it
3. Tick **Audio, AirPlay, and Picture in Picture**

### 5. Run the app

Select your iPhone as the run destination and press **⌘R**.

> ⚠️ **Use a real device.** The Simulator cannot open the Files app document picker and cannot play audio through AVFoundation reliably. All meaningful testing should be done on a physical device.

---

## Running Tests

Press **⌘U** to run the full test suite, or click the diamond icon next to any individual test class or method.

Tests use an in-memory SwiftData container so no data is written to disk. Each test that touches the file system uses an isolated temp directory that is cleaned up in `tearDown`.

> **Note:** AVFoundation playback tests (`PlaybackViewModelTests`) cannot test actual audio output in the test host — there is no audio hardware available. Those tests cover all state-machine logic and document the no-player boundary behaviour. Playback integration testing must be done manually on a real device.

---

## Architecture

The app follows a straightforward **MVVM** pattern:

- **Views** are pure SwiftUI and own no business logic
- **ViewModels** are `ObservableObject` classes (or `@Observable` where appropriate) that own state and expose methods
- **Models** are SwiftData `@Model` classes — the single source of truth for persisted data
- **Services** are stateless helpers (`enum` or `final class` singleton) for platform concerns like audio session and file duration

**Navigation stack:**

```
AudioLibraryView  (home)
  └── SectionsListView  (per-file)
        ├── SectionFormView  (sheet — create/edit)
        │     └── LiveMarkingView  (sheet — tap-to-mark)
        └── PlaybackControlsView  (ZStack overlay — active playback)
```

**Playback architecture note:** `PlaybackViewModel` is shared from `SectionsListView` down to `SectionFormView` and `PlaybackControlsView` so they all share the same `AVAudioPlayer` instance. This is intentional — it avoids multiple players competing for the audio session.

---

## Data Model

### `AudioFile`
| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `filename` | `String` | Used for export/import matching |
| `localPath` | `String` | Relative path in app Documents directory |
| `dateAdded` | `Date` | Import timestamp, used for library sort |
| `sections` | `[AudioSection]` | Cascade delete on file removal |

### `AudioSection`
| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `name` | `String` | User-defined label |
| `startTime` | `TimeInterval` | Seconds from start of file |
| `endTime` | `TimeInterval` | Seconds from start of file |
| `lastPlayed` | `Date` | Set to creation date on init; updated on each play |
| `playbackMode` | `PlaybackMode` | `.loop` or `.playOnce` — default: `.loop` |
| `audioFile` | `AudioFile?` | Parent relationship |

### JSON Export Schema

```json
{
  "filename": "my_track.mp3",
  "sections": [
    {
      "name": "Chorus",
      "startTime": 62.0,
      "endTime": 94.5,
      "lastPlayed": "2026-04-01T10:30:00Z",
      "playbackMode": "loop"
    }
  ]
}
```

---

## Key Design Decisions

**Why `AVAudioPlayer` over `AVPlayer`?**
`AVAudioPlayer` supports `enableRate` for pitch-preserving speed control and `numberOfLoops = -1` for native infinite looping — both core features. `AVPlayer` would require more complex setup for the same result.

**Why native looping (`numberOfLoops = -1`) instead of a timer?**
A `Timer` on the main `RunLoop` is suspended when the app is backgrounded, breaking loop behaviour with the screen off. `numberOfLoops = -1` loops at the audio buffer level inside AVFoundation — it works regardless of app state.

**Why copy audio files into the app sandbox instead of using security-scoped bookmarks?**
Bookmarks require ongoing renewal and can become stale when the user moves or renames files in the Files app. Copying gives the app a stable, owned reference with no maintenance burden, at the cost of disk space. For the expected file sizes (≤15 min MP3/WAV/M4A) this is acceptable.

**Why filename for export/import matching?**
A file hash would be more robust but adds meaningful latency for larger files. Filename is a pragmatic MVP choice — documented in the BRD and easily upgraded to a hash in a future version.

**Why `SectionFormView` accepts an optional `PlaybackViewModel`?**
This keeps the form fully functional in contexts without a player (e.g. editing a section when nothing is playing) while enabling the live-marking feature when a player is available. It avoids force-unwrapping and makes the dependency explicit.

---

## Known Limitations

- **File identity is by filename only** — renaming an audio file before re-importing will cause a JSON import mismatch
- **Simulator limitations** — the Files app document picker and AVFoundation audio do not work reliably in the iOS Simulator; always test on a real device
- **No waveform visualiser** — planned for a future release
- **No Spotify or streaming integration** — the Spotify iOS SDK does not support pitch-preserving speed control, which is a core feature; local files only for MVP
- **No iCloud sync** — all data is local to the device it was created on

---

## Roadmap

Planned post-MVP features:

- [ ] Waveform visualiser for timeline and section creation
- [ ] Additional audio format support beyond MP3, WAV, M4A
- [ ] Mini-player while browsing the library
- [ ] Per-section speed memory
- [ ] iPad support
- [ ] Additional sort/filter options (by section count, by duration)

---

## Contributing

Contributions are welcome. Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Run the full test suite: **⌘U** — all tests must pass
5. Add tests for any new logic in `ViewModels`, `Models`, or `Utilities`
6. Open a pull request with a clear description of what changed and why

**Code style:** Follow existing patterns — SwiftUI views stay thin, logic lives in ViewModels, no force unwraps, no `@MainActor` on class declarations (use per-method annotation instead to avoid `ObservableObject` conformance issues in Swift 6).

**Before opening a PR, check:**
- [ ] Build succeeds with no warnings
- [ ] All existing tests pass
- [ ] New logic has unit test coverage
- [ ] No new `// TODO:` comments left unaddressed

---

## Contact

**Le Minh Giang**
mgiang2015@gmail.com
[Github](https://github.com/mgiang2015/)
[LinkedIn](https://www.linkedin.com/in/leminhgiang/)

For bug reports and feature requests, please open an issue on GitHub rather than emailing directly.
