# PocketLLM (Xcode project: IOSassignment) — Agent Instructions

Full plan: `~/Downloads/PROG3230-DEV-PLAN.md` (read it before starting any phase).

## Decisions of record
- iOS Deployment Target: **16.0** — set and verified on project + target, Debug + Release (Deyi, 2026-10-05). Deyi confirmed iOS 16; instructor's own reply is not recorded here yet
- Inference package: `john-rocky/swift-litert-lm` (SPM). Fallback: `LocalLLMClient`
- Test device: iPhone 14 Plus, A15, iOS 26.6. RAM believed 6 GB (not yet confirmed on device — About screen shows it). Deyi has run Gemma smoothly in Google's own app on this phone, so try Gemma 4 E2B with allowUnsafeMemory after the small-model rung works.
- Plan changes: Settings screen built before the model work (engine switch lives there); first model rung = litert-community/Qwen3-0.6B
- Project Format: **Xcode 12.0-compatible** (compatibilityVersion "Xcode 12.0"), storyboards already old format (toolsVersion 13122). Re-verify before submission.
- New files: written with Xcode MCP `XcodeWrite` (Xcode adds them itself; format stays intact). Folder is a synchronized group.
- Scheme name: `IOSassignment` (plan's `PocketLLM` examples map to this)

## Never edit
project.pbxproj, anything under *.xcodeproj or *.xcworkspace,
*.storyboard, *.xib, *.entitlements, Assets.xcassets.
If a change needs one of these, stop and emit "HUMAN ACTION REQUIRED".

## Conventions
- UIKit + Storyboard. No SwiftUI.
- Dependencies via Swift Package Manager only. Never CocoaPods.
- All user-facing strings via NSLocalizedString, authored in en + zh-Hans.
- Inference runs off the main thread; only UI updates hop to main.
  Never silence a concurrency warning with @MainActor to make it go away.
- Every user-reachable throw surfaces as a UIAlertController that names
  the failure and the next step.
- Comment public types and any non-obvious control flow. Comments are graded.

## Build & verify
Xcode MCP (BuildProject) or:
xcodebuild -scheme IOSassignment \
  -destination 'platform=iOS Simulator,name=iPhone 17' build | xcbeautify

## After every phase
Update DESCRIPTION.md. Unrecorded work is ungraded work.
