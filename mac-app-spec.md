# Conversation Assistant — Mac App Design Spec
*For use with Claude Code + Figma*

---

## Overview
A native macOS app that listens to conversations in real time and either transcribes them, suggests follow-up questions and threads, or both — depending on the mode. Designed for researchers, designers, and knowledge workers running interviews, exploratory calls, and project meetings. Built for focus: minimal UI, low cognitive load, stays out of the way while you talk.

---

## App Structure

The app has two primary surfaces:

### 1. Main Window
The primary working view, visible during a session. Compact, designed to float alongside a video call without taking up too much screen real estate.

### 2. Script / Guide Panel
A separate floating window that displays the current session's guide (research script, conversation guide, or empty). Stays open during a session for reference. Can be positioned independently on screen.

---

## Main Window Layout

**Header bar** (top of window)
- App name / logo (left)
- Gear icon → opens Settings (right)
- Recording indicator dot — grey when idle, red and pulsing when active

**Pre-session setup area** (visible before session starts, collapses on start)
- **Project** — dropdown, populated by scanning the `/projects` folder. Lists subfolder names.
- **Mode** — dropdown, populated from config file. Examples: "User Interview", "Exploratory Conversation", "Work Call", "Meeting Notes"
- **Audio Input** — dropdown, lists all available Core Audio input devices (microphone, BlackHole, etc.). Defaults to system default input. Selection persists across sessions.
- **Session name** — text field, pre-populated with `YYYY-MM-DD-[project-name]`, fully editable
- **Suggestions** — toggle switch, on or off. When off, transcription only. When on, AI suggestions appear in real time.
- **Start Session** button — prominent, activates recording and collapses the setup area

**Suggestions panel** (right side or main body, visible when suggestions are ON)
- Scrolling list of suggestion cards, newest at top
- Each card shows a suggested question or thread — clean, readable, one idea per card
- Cards fade in as they appear — no jarring pop
- When suggestions are OFF, this area shows a simple "Recording…" state with a waveform or minimal animation

**Transcript strip** (bottom of window)
- Shows last 2–3 lines of live transcript
- Small, secondary — just enough to confirm transcription is working
- Tap/click to expand to full transcript view (optional)

**Footer bar**
- **End Session** button — ends recording, saves transcript to `/projects/[project]/raw/[session-name].txt`
- Session timer (elapsed time)
- Open Guide button — toggles the Script / Guide Panel

---

## Script / Guide Panel

- Separate floating window, independently positionable
- Displays contents of `guide.txt` for the selected project (if it exists)
- Editable inline — changes save back to `guide.txt` on save
- **Save** button at bottom
- If no guide file exists, shows a placeholder: *"No guide for this project. Add a guide.txt file to the project folder, or type one here."*
- Window title shows project name + mode

---

## Settings Panel

Accessible via gear icon. Opens as a modal or slide-in sheet.

**Sections:**

**General**
- Model selector: Haiku / Sonnet (radio or segmented control)
- Suggestion frequency: segmented control (20s / 40s / 60s / Manual). Selecting Manual turns the segment into an editable integer input field (minimum 10s).
- Prompt caching: toggle (on by default)
- Audio input: dropdown listing all available Core Audio input devices. Mirrors the pre-session selector — changing either one updates the other.

**Projects**
- Projects root folder: file path with "Choose…" button to set location
- "Open in Finder" button — reveals the projects folder
- List of detected projects (read-only, just shows what's there)

**Modes**
- List of configured modes pulled from config file
- Read-only display of mode names and a brief description of each instruction set
- "Edit config file" button — opens the config file in default text editor

**About**
- Version number
- API key field (masked) with a "Test connection" button

---

## Visual Design Direction

Native macOS feel — not a web app wrapped in a window. Follow macOS design conventions:
- Use system fonts (SF Pro)
- Standard macOS controls: segmented controls, toggles, dropdowns, sheet modals
- Dark mode support
- Translucent sidebar/panel materials (NSVisualEffectView) where appropriate
- Compact default window size — app should feel like a utility, not a workspace
- Accent color: consider a calm blue or neutral — avoid anything that feels urgent or alarming

**Window sizing:**
- Main window: approximately 380–420px wide, height scales with content
- Script panel: approximately 480px wide, freely resizable vertically
- Settings: modal sheet, approximately 460px wide

---

## Folder Structure (for reference)
```
/projects
  /pilot-project
    guide.txt            ← session guide, shown in Script Panel
    background.md        ← loaded into AI context
    summary.pdf          ← loaded into AI context
    /raw                 ← ignored, never loaded into context
      2026-03-01-session.txt
  /victoria-rork
    guide.txt
    attentional_design_summary.md
    /raw
  /scratch
    /raw
```

---

## Key Behaviors
- Selecting a project loads all files from that folder (except `/raw`) into AI context at session start
- `guide.txt` if present is displayed in the Script Panel and used as the session guide
- Session transcript auto-saves to `/raw/[session-name].txt` on End Session
- Mode selection loads the corresponding instruction block from config
- Suggestions toggle off = transcription only, no AI calls, no suggestion panel
- App should request microphone permission on first launch with a clear explanation of why
