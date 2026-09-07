# Conversation Assistant — macOS App PRD

---

## Overview

A native macOS app that listens to conversations in real time, transcribes them locally using Apple's Speech framework, and uses Claude to suggest follow-up questions based on the conversation and a pre-loaded session guide. Designed for researchers, designers, and knowledge workers running interviews, exploratory calls, and project meetings. Minimal UI, low cognitive load, stays out of the way while you talk.

---

## Goals

- Replace the Electron interview assistant with a proper native macOS app
- Support multiple conversation modes (User Interview, Exploratory Conversation, Work Call, Meeting Notes)
- Organise sessions around a projects folder — each project carries its own guide and context files
- Let the user choose any Core Audio input device (mic or BlackHole for system audio capture)
- Keep all audio transcription on-device using Apple Speech — no audio ever leaves the machine
- Keep AI suggestions optional — the app is useful for transcription alone

## Non-Goals (MVP)

- PDF or image file support in project context (text and markdown only)
- Multi-user or cloud sync
- Distribution outside personal use (no notarization required for now)
- Exporting or sharing transcripts from within the app

---

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Swift |
| UI | SwiftUI |
| Transcription | Apple Speech framework (`SFSpeechRecognizer` + `AVAudioEngine`) |
| AI | Anthropic API via `URLSession` (no SDK — direct HTTP) |
| Persistence | `UserDefaults` for settings; plain files for projects and transcripts |
| Audio routing | Any Core Audio input device, including BlackHole |

---

## App Structure

Two primary surfaces:

1. **Main Window** — pre-session setup and active session view
2. **Script / Guide Panel** — separate floating window showing the session guide, independently positionable

Settings are accessible via a gear icon and open as a standard macOS settings window.

---

## Screen Specifications

### Main Window — Pre-Session

The setup form shown before a session starts.

**Fields:**
- **Project** — dropdown, populated by scanning the configured projects root folder. Lists subfolder names. Selecting a project loads its file count.
- **Mode** — dropdown, populated from the modes config. Selecting a mode loads its system prompt.
- **Audio Input** — dropdown, lists all available Core Audio input devices. Defaults to system default input. Selection persists across launches.
- **Session Name** — text field, pre-populated with `YYYY-MM-DD-[project-name]`, fully editable.
- **Suggestions** — toggle. On = AI suggestion cards appear during session. Off = transcription only, no Claude calls.
- **Start Session** — prominent full-width button. Activates recording and collapses the setup form.

**Header:**
- Gear icon (right) → opens Settings
- Recording indicator dot — grey when idle

---

### Main Window — Active Session

Setup form collapses. The working view during a live session.

**Header:**
- Window title: `[project-name] — [mode]`
- Gear icon (right)
- Recording dot — red and pulsing while active

**Suggestions panel** (when suggestions are ON):
- Scrolling list of suggestion cards, newest at top
- Each card: single question or thread suggestion, clean readable text
- Cards fade in on appearance — no jarring pop
- Clicking a card highlights it in accent blue (marks it as "want to ask this")
- Clicking a highlighted card un-highlights it
- When suggestions are OFF: shows a simple "Recording…" state

**Transcript strip** (bottom of suggestions panel):
- Shows last 2–3 lines of live transcript text
- Small, secondary — confirms transcription is working
- Streaming — updates as Apple Speech returns partial and final results

**Footer:**
- **Open Guide** (left) — toggles the Script / Guide Panel
- Session timer — elapsed time, centered
- **End Session** (right, red) — stops recording, saves transcript, resets to pre-session view

---

### Script / Guide Panel

Separate floating window, independently positionable on screen.

- Window title: `[project-name] — [mode]`
- Displays contents of `guide.txt` from the selected project, formatted and readable
- Editable inline — textarea with full content
- **Save** button — writes changes back to `guide.txt`
- "Unsaved changes" label appears when content has been modified but not saved
- If no `guide.txt` exists: shows placeholder text — *"No guide for this project. Start typing to create one."*
- Approximately 480px wide, freely resizable vertically

---

### Settings — General

- **Model** — segmented control: `Haiku (Fast)` / `Sonnet (Powerful)`
- **Suggestion Frequency** — segmented control: `20s` / `40s` / `60s` / `Manual`. Selecting Manual converts the control to an integer input field (minimum 10s, no maximum).
- **API Key** — masked text field with a **Test** button. Test makes a minimal API call and shows success/failure inline.
- **Prompt Caching** — toggle, on by default. Controls whether `cache_control` is sent on system prompt and context blocks.
- **Audio Input** — dropdown listing all Core Audio input devices. Mirrors the pre-session selector.

---

### Settings — Projects

- **Projects Folder** — text field showing current path (default: `~/Documents/projects`) with a **Choose…** button to change it via native file picker.
- **Open in Finder** — reveals the projects root folder.
- **Detected Projects** — read-only list showing subfolder names and file counts from the projects root. Refreshes when folder path changes.

---

### Settings — Modes

- **Configured Modes** — list of mode cards, each showing name and description.
- Each card is a tappable button that opens the **Mode Editor**.

**Mode Editor** (sheet modal):
- Title: mode name
- `MODE` label badge in header
- Instructional text: *"Edit the system prompt that shapes AI behaviour in this mode."*
- Textarea — pre-populated with the mode's current system prompt, fully editable
- Token count estimate (bottom right of textarea, e.g. `~180 tokens`)
- **Reset to default** (left, destructive) — reverts to the built-in default prompt for this mode
- **Save** and **Cancel** buttons (right)
- Changes persist to the modes config file

---

### Settings — About

- App name and icon
- Version number
- **Resources** section:
  - Documentation link
  - Report an Issue link
  - Acknowledgements (Anthropic, OpenAI Whisper)

---

## Audio Pipeline

```
AVAudioEngine
  └── inputNode (set to selected Core Audio device)
        └── audio buffer tap (1024 samples, 44.1kHz)
              └── SFSpeechAudioBufferRecognitionRequest
                    └── SFSpeechRecognizer (on-device, en-US default)
                          └── streaming SFTranscriptionSegment results
                                └── transcript updated in real time
```

**Key behaviours:**
- On-device recognition requested by default (`requiresOnDeviceRecognition = true` if available, fallback to server-based if not)
- Partial results enabled — transcript strip updates as the person speaks
- Final results committed to the full session transcript string
- On End Session: recognition request is finished, final transcript written to disk

**Permissions:**
- Microphone access (`NSMicrophoneUsageDescription`) — requested on first launch with a clear explanation
- Speech recognition (`NSSpeechRecognitionUsageDescription`) — requested on first launch

---

## AI Integration

**Trigger:** A new suggestion is generated every N seconds (per Suggestion Frequency setting), measured from when the last suggestion was generated. The timer only runs while transcript content is growing — no call made if nothing new has been said.

**What gets sent to Claude:**

1. **System prompt** — the selected mode's instruction block. Sent with `cache_control: ephemeral`.
2. **Project context** — all text/markdown files from the project folder (excluding `/raw`), concatenated. Sent with `cache_control: ephemeral`.
3. **Session guide** — contents of `guide.txt` if present. Sent with `cache_control: ephemeral`.
4. **Existing suggestions** — the current list of suggestions shown in the UI, to avoid duplication.
5. **Full transcript so far** — grows throughout the session. Not cached (changes every call).

**Response format:** A JSON array containing exactly one question string.

```json
["What made that moment feel different from the others?"]
```

**On error:** No card is added. A subtle warning appears below the last card (not counted toward any cap). Next trigger cycle proceeds normally.

**When suggestions are OFF:** No Claude calls are made at any point.

---

## Projects & File Structure

```
~/Documents/projects/          ← configurable root
  /pilot-project/
    guide.txt                  ← displayed in Script Panel, included in AI context
    background.md              ← included in AI context
    /raw/                      ← never loaded into context
      2026-03-01-session.txt
  /victoria-rork/
    guide.txt
    attentional_design_summary.md
    /raw/
  /scratch/
    /raw/
```

**Rules:**
- All `.txt` and `.md` files in the project root (not in subdirectories) are loaded into AI context at session start
- The `/raw` subfolder is explicitly excluded from context
- `guide.txt` is also displayed in the Script Panel
- Session transcript saved to `/raw/[session-name].txt` on End Session
- PDF, image, and other file types are ignored (future enhancement)

---

## Modes Config

Modes are stored in a local config file (`~/Library/Application Support/ConversationAssistant/modes.json`).

Each mode has:
- `id` — unique identifier
- `name` — display name
- `description` — one-line summary shown in the Modes list
- `systemPrompt` — the full instruction block sent to Claude
- `isDefault` — bool, used by Reset to default in the Mode Editor

Four default modes ship with the app:
- **User Interview** — focused on discovering user needs, pain points, and mental models
- **Exploratory Conversation** — open-ended discovery, surfaces threads worth pulling on
- **Work Call** — meeting-focused, lighter suggestion cadence
- **Meeting Notes** — transcription only, no AI suggestions regardless of the Suggestions toggle

---

## Persistence

| Data | Storage |
|---|---|
| API key | Keychain (`SecItemAdd` / `SecItemCopyMatching`) |
| Selected model | `UserDefaults` |
| Suggestion frequency | `UserDefaults` |
| Prompt caching toggle | `UserDefaults` |
| Projects root folder | `UserDefaults` |
| Last selected project | `UserDefaults` |
| Last selected mode | `UserDefaults` |
| Last selected audio input | `UserDefaults` |
| Modes config | `~/Library/Application Support/ConversationAssistant/modes.json` |
| Session transcripts | `/projects/[project]/raw/[session-name].txt` |
| Guide files | `/projects/[project]/guide.txt` |

---

## Build Phases

### Phase 1 — App shell + settings
- SwiftUI app scaffold with correct window structure
- Settings window with all four tabs (General, Projects, Modes, About)
- Modes config file read/write
- Mode Editor sheet
- UserDefaults persistence for all settings
- API key test connection

### Phase 2 — Projects + Script Panel
- Projects folder scanning and display
- Script / Guide Panel (floating window, independent positioning)
- guide.txt load, display, edit, and save
- Project context file loading (all .txt/.md in project root)

### Phase 3 — Audio + Transcription
- AVAudioEngine setup with device selector
- SFSpeechRecognizer integration (on-device preferred)
- Microphone + speech recognition permission flow
- Pre-session → active session → end session lifecycle
- Live transcript strip
- Transcript auto-save to /raw on End Session

### Phase 4 — AI Suggestions
- Claude API integration (direct HTTP, no SDK)
- Suggestion frequency timer
- Suggestion cards UI (fade in, highlight on click, newest at top)
- Deduplication via existing suggestions list in prompt
- Prompt caching on system prompt + context blocks
- Error handling (warning card, silent skip)

### Phase 5 — Polish
- Animations and transitions (session start collapse, card fade-in)
- Recording indicator dot pulse animation
- Empty states and edge cases
- Full dark mode audit
- End-to-end test with live audio

---

## Success Criteria

- An interviewer can launch the app, select a project and mode, hit Start, and see live transcript and suggestions within 30 seconds — with no external services required beyond the Anthropic API
- Suggestions are genuinely useful and non-repetitive within a session
- The app is unobtrusive enough to use during a real interview — glanceable, not distracting
- BlackHole can be selected as the audio input to capture system audio from a video call
- All audio processing happens on-device
