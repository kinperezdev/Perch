# Perch

**Protect the builder while they build.**

Perch is an AI wellbeing companion for macOS. It lives near the MacBook notch, quietly watches safe signals (active session length, idle time, your calendar with permission), and checks in at the right moments: water, stretch, meals, meeting prep, overwork, wind down. It is not a task manager and not a productivity tracker. It is someone looking out for you while you're locked in.

Built with Swift, SwiftUI, AppKit, and RevenueCat. Targets macOS 26 (Tahoe).
Built for the RevenueCat Shipaton 2026; see [SHIPPING.md](SHIPPING.md) for the Mac App Store release checklist. Licensed under [MIT](LICENSE).

## Intelligence, free and private

Perch composes its check ins and support chat with whatever intelligence is available, at no cost to the user, and falls through gracefully:

1. **Apple Intelligence** (FoundationModels) on device, fully private.
2. **Local Ollama** model if one is running, auto-detected on `127.0.0.1:11434`.
3. **Optional cloud** (OpenAI, Gemini, Anthropic) only if the user turns on Online mode and pastes their own key, stored in the Keychain.
4. **Curated message library** as the always-available fallback, so nothing ever feels broken.

A local **PerchBrain** records habits (water, breaks, focus sessions, which reminders you accept or ignore) into a private JSON file and feeds that context back into the prompts, so check ins get more personal over time.

## The new Apple stack it uses

- **FoundationModels (Apple Intelligence)**: check in lines and the emotional support chat are composed on device in the voice of your chosen personality.
- **Liquid Glass**: `glassEffect` surfaces and `.glass` / `.glassProminent` button styles across the menu bar popover, paywall, and weekly summary.
- **App Intents**: "Log water", "Check on me", and "I took a break" work from Spotlight, Shortcuts, and Siri.
- **Observation (`@Observable`)**, **Swift Concurrency** end to end, **MenuBarExtra**, **SMAppService** launch at login, **EventKit** full access API, **Carbon hot keys** for the global quick answer shortcut (no accessibility permission needed).

## Running it

```bash
open Perch.xcodeproj   # then press Run in Xcode
```

or from the terminal:

```bash
xcodebuild -project Perch.xcodeproj -scheme Perch -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Perch.app
```

First launch opens onboarding: name, personality, work rhythm, care preferences, permissions, and the quick answer shortcut (default: Control + Option + Space).

### Demo mode (important for judging)

Settings > General > **Demo mode** makes time run 60x faster: one real second counts as one minute of focus. A "3 hour" overwork check in arrives in about 3 minutes of real use. The menu bar shows a DEMO badge while it is on.

### Trying the core loop fast

1. Turn on Demo mode.
2. Keep using your Mac. Water and stretch check ins appear at natural pauses.
3. Press the quick answer shortcut from any app: keys 1, 2, 3 answer instantly, Esc dismisses.
4. Click the menu bar bird > **Talk** to open the emotional support chat under the notch.
5. Menu bar > **Check on me** forces the most relevant check in immediately.

## RevenueCat

The app is configured **live** with a RevenueCat Test Store key (`SubscriptionManager.embeddedAPIKey`, override with env `PERCH_REVENUECAT_KEY`). Setup expected in the dashboard:

- Entitlement: `Perch Pro` (active = every feature unlocked)
- Products: `lifetime`, `yearly`, `monthly`, all attached to the `Perch Pro` entitlement
- A current Offering containing those three packages, plus a Paywall built in the dashboard Paywalls tab

The app ships its own paywall (`PerchPaywallView`) backed by real RevenueCat offerings and packages, showing free-trial text when a product has an introductory offer. Purchases and restores run through `Purchases.shared` (async StoreKit 2), and entitlement state stays fresh through `customerInfoStream`. Manage subscription lives in Settings > Plan (Customer Center is iOS only for now, so macOS hands off to App Store subscriptions plus in-app restore). Without a key, the app falls back to demo mode with simulated purchases.

Key resolution in `SubscriptionManager`: `PERCH_REVENUECAT_KEY` env override, then the `appl_` production key, then the `test_` Test Store key, then demo. Test purchases end to end locally with the included `Config/Perch.storekit` (Edit Scheme > Run > Options > StoreKit Configuration). The full release path is in [SHIPPING.md](SHIPPING.md).

## Architecture

```
Perch/
├── App/            PerchApp, AppDelegate, AppContainer (composition root),
│                   WindowPresenter, PerchIntents
├── Core/
│   ├── Models.swift                  Plans, gates, reminder kinds, check ins
│   ├── PreferencesStore.swift        Settings, persisted per property
│   ├── HabitMemoryStore.swift        Local JSON memory + adaptivity + weekly summary
│   ├── FocusSessionTracker.swift     Active/idle signal from event timing only
│   ├── ReminderEngine.swift          Context rules, natural pause delivery, cooldowns
│   ├── PersonalityEngine.swift       6 personalities + custom companion
│   ├── MessageLibrary.swift          Curated voice of Perch (always available)
│   ├── CompanionIntelligence.swift   FoundationModels generation + fallback
│   ├── CompanionChatService.swift    Support chat, safety routing, AI or curated
│   ├── CompanionCoordinator.swift    Bubble state machine (message/voice/timer/chat)
│   ├── CalendarAwarenessService.swift  EventKit, read only, next 24h
│   ├── VoiceService.swift            Speech out + on-device recognition in
│   ├── QuickAnswerShortcutManager.swift  Carbon global hotkey + key naming
│   ├── SubscriptionManager.swift     RevenueCat + demo fallback
│   └── NotificationService.swift     Optional notification mirror
└── UI/
    ├── Notch/       NotchPanelController (NSPanel), NotchCompanionView,
    │                CompanionFaceView, CompanionChatView
    ├── MenuBar/     MenuBarContentView
    ├── Onboarding/  OnboardingView
    ├── Paywall/     PaywallView
    ├── Settings/    General, Care, Personality, Shortcut, Privacy, Plan
    └── Weekly/      WeeklySummaryView
```

How the loop works: `ReminderEngine` ticks every 5 seconds, feeds `FocusSessionTracker`, and evaluates rules (water, stretch, eyes, posture, walk, meals by your usual times, overwork milestones, wind down, sleep, meeting prep and recovery, personal routines). Candidates wait for a natural micro pause in typing before delivery, respect global cooldowns, quiet hours, pause state, and meetings. `HabitMemoryStore` records every response; kinds you keep ignoring at a certain time of day get quieter, kinds you accept get slightly more attentive (Pro).

## Privacy

- Signals used: session duration, idle time, calendar events (with permission), your responses. That's all.
- Never read: messages, documents, passwords, browser or screen content.
- Memory is one local JSON file (`~/Library/Application Support/Perch/memory.json` inside the sandbox container), deletable from Settings > Privacy.
- Chat conversations are never written to disk.
- AI runs on device via Apple Intelligence. The only network use is RevenueCat, and only when a key is configured.
- The app is sandboxed.

## Emotional support, not therapy

The chat offers supportive reflection, one practical next step, and grounding. It never claims to be therapy or medical care. Messages that signal serious distress get a fixed, caring response that points to real people: someone you trust, local emergency support, 988 in the US, NCMH 1553 in the Philippines.

## Known scope cuts (deliberate, MVP)

- No dashboards, no teams, no social features.
- Calendar awareness, voice, AI chat are Pro gated by design.
- Unit tests are the next step: `ReminderEngine` rules, `HabitMemoryStore` adaptivity, and `VoiceService.interpret` are pure enough to test directly.
