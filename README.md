# PocketLLM — an LLM that runs on the iPhone itself

Course project for PROG3230 (Mobile Application Development II). You type a message and a
language model running **on the phone** answers: no network, no server.
UIKit + Storyboard (a course requirement, no SwiftUI), Swift Package Manager, **minimum iOS 16**.

## Status

| Feature | State |
|---|---|
| Chat screen: send/stop, streaming, error alerts | Done |
| Settings screen: streaming switch, max-words stepper, engine picker (saved across launches) | Done |
| Settings: temperature slider | Stored, not yet passed to the model |
| On-device model (Qwen3-0.6B), English and Chinese | Works **on a physical iPhone only** (iPhone 14 Plus: ~14 tokens/s, first word < 1 s) |
| About screen | Code written, Storyboard screen not built |
| Core Data history, model manager, camera, zh-Hans strings file | Not started |

## Design

- **`InferenceEngine` protocol** is the core. Screens only talk to it, so a new model means a new
  implementation and no UI changes.
- **`MockEngine`** (default): canned keyword replies that run anywhere. This is what a grader sees in the Simulator.
- **`LiteRTEngine`**: the real model, via [swift-litert-lm](https://github.com/john-rocky/swift-litert-lm)
  pinned to 0.2.0. Qwen3-0.6B (614 MB) downloads inside the app on first use and lives in the app
  sandbox, never in git.

## Run it

1. Clone, open `IOSassignment.xcodeproj` in Xcode (we use Xcode 27), wait for the package to resolve (network needed).
2. **Simulator:** just run. It uses the Mock engine.
3. **Physical device:** connect an iPhone, pick your own Team under Signing & Capabilities, run, then
   Settings → **On-device**. The first question downloads the model (use Wi-Fi).

## Team rules (learned the hard way)

- Never hand-edit `project.pbxproj` or `.storyboard` files. Change project settings, controls and connections in Xcode only.
- Keep the project format at **Xcode 12.0-compatible** and the deployment target at **iOS 16**. Newer Xcode
  versions silently upgrade them; check before every commit.
- One person per Storyboard at a time. Its merge conflicts are practically unresolvable.
- Don't press Return after selecting a file in the navigator: it starts a rename. This already
  renamed `Main.storyboard` by accident twice.
- Don't choose On-device in the Simulator. The model's output there is garbled (confirmed; the same code is correct on a device).
- New Swift files go inside `IOSassignment/` and are picked up automatically.

## Known issues / open tasks

1. Xcode 27 upgraded the Storyboards to a newer format (`toolsVersion` 25098). The instructor's Xcode 16
   may not open them. Unresolved; needs checking with the instructor.
2. The instructor has not yet confirmed iOS 16 as the minimum (every on-device model library requires 16+).
3. Try Gemma 4 E2B. The package refuses devices under 7 GB RAM; the iPhone 14 Plus has 6 GB, so it needs `allowUnsafeMemory`.
4. Auto-generated Auto Layout constraints are rough (narrow text field, truncated label). Grading requires
   Content Hugging / Compression Resistance on the composer row.
5. An emoji split across two model tokens can show up as garbage (e.g. `ĠðŁĺ`). Intermittent.
6. `DESCRIPTION.md` (the document the course grades from) does not exist yet.

## Layout

`Engines/` inference engines · `Controllers/` screens · `Support/` settings storage and output filter ·
`CLAUDE.md` project rules for the AI coding assistant.
