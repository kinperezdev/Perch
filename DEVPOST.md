# Perchie - Protect the builder while they build.

## Inspiration
I built Perchie because I lived it. Chasing this dream, I'd get so locked into building that I forgot to take care of myself. Skipped meals, ignored water, sat in the same terrible posture for hours.

I didn't want any other builder to end up like me.

Everything out there measures output or demands attention. Productivity trackers make you anxious about numbers. Task managers make you stop and context-switch. I needed something that cared about me, not my metrics, without ever breaking my flow.

## What it does
Perchie is a tiny AI wellbeing companion that lives right in your MacBook's notch. It quietly watches safe, private signals in the background: how long you've been focused, your idle time, your calendar, and checks in at the exact right moment. Not on a rigid timer. It waits for a natural pause in your work, then drops down from the notch to ask if you need water, a stretch, a meal, or a break.

Every check-in is a single tap. No typing, no chatbot, no leaving your flow. Pick one of six personalities, Mom, Homie, Assistant, Mentor, Coach, or Spark, and Perchie talks to you the way you'd actually want to be talked to.

It's not a productivity tracker. It's a companion looking out for you while you're locked in.

## How we built it
Built entirely native for macOS with Swift, SwiftUI, and AppKit, targeting the newest OS.

- **Design**: A custom Liquid Glass system for the notch drop-down and dashboard, `glassEffect` throughout, built to feel like a real part of macOS rather than an overlay bolted on top.
- **Intelligence**: On-device Apple Intelligence (FoundationModels) generates check-in lines with zero cloud calls. If it's unavailable, Perchie falls back to a local Ollama model, then to a curated message library, so it never feels broken.
- **PerchBrain**: A local memory store that learns your habit timing (when you actually eat, drink, shower, focus) and feeds that back into every check-in so the companion sounds like it knows you.
- **Monetization**: RevenueCat with StoreKit 2, a 3-day full-access trial with zero features held back, then a straightforward paywall.
- **Shipping**: Full Mac App Store submission pipeline, including two rounds of App Review fixes.

## Challenges we ran into
Keeping an always-on menu bar app from eating CPU meant leaning entirely on event timing and idle detection instead of polling. Getting the notch panel to drop down without stealing window focus took real `NSPanel`/AppKit work most SwiftUI apps never touch.

The harder challenge showed up after building: App Store Review. Our first submission got rejected for a leftover entitlement with no code behind it, and an unreviewed in-app purchase. We fixed both, resubmitted, and got rejected again, this time for permission-button wording that looked too close to the system dialog's own "Allow" button, and for black text on a dark background that only showed up under macOS Light Mode, something we never saw locally because the app forces dark mode everywhere. Chasing that one taught us that `.preferredColorScheme(.dark)` in SwiftUI doesn't fully reach AppKit-backed controls like `DatePicker` inside a `Form`. Every raw window in the app now sets its real `NSAppearance` explicitly.

Late in the process we also cut WeatherKit and location-based sky entirely, in favor of a simple day/night-only sky. One less permission to ask for, one less thing that could break.

## Accomplishments that we're proud of
1. **The design.** The notch integration and glass animations feel premium enough that people assume it's an Apple feature, not a hackathon build.
2. **The non-toxic AI.** Perchie never lectures, never mentions productivity metrics, never guilt-trips. It's strictly on your side.
3. **Getting through App Review.** Turning two rejections into fixes we could point to a specific guideline for, on our own, by reading the review notes closely instead of guessing.

## What we learned
Small on-device models can't be trusted with logic, only with words. We once asked the model to judge "is it late right now" from a timestamp in the prompt. It couldn't, and told users to go to sleep at 2 PM. The fix: Swift decides every condition, the model only phrases the sentence. Decide in code, speak with AI.

Choices beat conversation for a reminder app. We built a full chatbot with dictation, then watched it pull people away from the one thing Perchie is for. Nobody deep in focus wants to compose a message. They want to tap "drank water" and get back to work. We deleted the entire chat path rather than leave it dormant behind the UI.

App Review isn't adversarial, it's specific. Every rejection came with an exact guideline and an exact fix. Read it literally before assuming it's a design opinion.

Dark mode in SwiftUI is a promise the framework makes, not a guarantee AppKit keeps. A `.preferredColorScheme(.dark)` on a view doesn't automatically reach a raw `NSWindow` hosting it. Set the real appearance yourself, every time.

## What's next for Perchie
Getting through App Review and live on the Mac App Store. After that, exploring iCloud sync for PerchBrain so your companion remembers you across every Mac you own, without ever leaving the device unencrypted or handing data to a server we control.

---
*I built this for you, and I hope you take care of yourself now, future founder.*
