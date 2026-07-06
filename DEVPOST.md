# Perch - Protect the builder while they build.

## Inspiration
I built Perch because I experienced this myself. I was getting sick chasing my dream. I would get so locked in and intensely focused on building that I completely forgot to take care of myself—skipping meals, ignoring hydration, and sitting in terrible postures for hours.

I don't want any builder to end up like me.

The tools currently available to us are either **productivity trackers** that induce anxiety by measuring output, or **task managers** that require context switching to use. I needed something that actively cared for my wellbeing without ever breaking my flow state.

## What it does
Perch is a tiny, beautiful AI wellbeing companion for macOS. It lives right near your MacBook notch.
It quietly watches safe, private signals in the background (active session length, idle keyboard time, and calendar events) and proactively checks in at the exact right moments. 

Instead of annoying, rigidly scheduled alarms, Perch waits for natural pauses in your typing to drop down smoothly from the notch and remind you to drink water, stretch, eat lunch, go to sleep when it's late, or physically step away when you are overworking yourself. You can also chat with Perch for quick emotional support to vent your stress, celebrate a coding win, or deal with imposter syndrome. 

## How we built it
Perch was built entirely natively for macOS using **Swift, SwiftUI, and AppKit**, targeting macOS Tahoe.

- **Design & UI**: We built a custom "Liquid Glass" design system to create fluid, beautiful `glassEffect` popovers and drop-down notch animations. We wanted Perch to feel like a premium, organic part of macOS.
- **Intelligence**: We integrated **Apple Intelligence** (FoundationModels) to securely generate deeply personal check-in messages on-device, preserving full user privacy. If Apple Intelligence isn't available, it falls back to a locally hosted Ollama model or a curated message library, meaning the app *never* feels broken.
- **The "PerchBrain"**: We built a local JSON memory store that tracks which reminders you dismiss and which ones you respond well to. The AI naturally adapts its personality and check-in frequency to match your specific rhythm.
- **Monetization**: We natively integrated **RevenueCat** using StoreKit 2 to handle our "Perch Pro" subscription, providing seamless access to unlock all personalities, calendar awareness, and deep AI chat support.

## Challenges we ran into
Building a global, always-on macOS menu bar app that doesn't consume extreme amounts of CPU was tough. We had to rely strictly on event timing and idle timers to determine if the user was focused, rather than polling the system. 
Making the "Notch companion" drop down smoothly without interrupting the user's active window required deep AppKit and `NSPanel` integration to bypass standard window focus rules.

## Accomplishments that we're proud of
1. **The Design**: The notch integration and liquid glass animations feel incredibly premium. We are extremely proud of how non-intrusive and visually stunning the companion feels. 
2. **The "Non-Toxic" AI**: We successfully trained the system prompts to be entirely supportive. Perch will never lecture you or mention productivity metrics. It is strictly a wellbeing companion.

## What we learned
Building a non-intrusive companion requires incredible restraint. We learned how to build complex "delivery rules" in Swift to ensure Perch only talks to you during natural micro-pauses in your work, preventing it from ever being annoying.

## What's next for Perch
We plan to release Perch on the Mac App Store officially! We want to expand the PerchBrain to sync securely via iCloud so your companion remembers your habits across multiple Macs.

---
*I built this for you, and I hope you take care of yourself now, future founder.*
