# Perch - Protect the builder while they build.

## Inspiration
I built Perch because I experienced this myself. I was getting sick chasing my dream. I would get so locked in and intensely focused on building that I completely forgot to take care of myself—skipping meals, ignoring hydration, and sitting in terrible postures for hours.

I don't want any builder to end up like me.

The tools currently available to us are either **productivity trackers** that induce anxiety by measuring output, or **task managers** that require context switching to use. I needed something that actively cared for my wellbeing without ever breaking my flow state.

## What it does
Perch is a tiny, beautiful AI wellbeing companion for macOS. It lives right near your MacBook notch.
It quietly watches safe, private signals in the background (active session length, idle keyboard time, and calendar events) and proactively checks in at the exact right moments. 

Instead of annoying, rigidly scheduled alarms, Perch waits for natural pauses in your typing to drop down smoothly from the notch and remind you to drink water, stretch, eat lunch, go to sleep when it's late, or physically step away when you are overworking yourself. Every check-in is answered with a single tap: quick-reply choices grounded in your actual day (water, meals, breaks, shower, focus time), so you never have to type or leave your flow.

## How we built it
Perch was built entirely natively for macOS using **Swift, SwiftUI, and AppKit**, targeting macOS Tahoe.

- **Design & UI**: We built a custom "Liquid Glass" design system to create fluid, beautiful `glassEffect` popovers and drop-down notch animations. We wanted Perch to feel like a premium, organic part of macOS.
- **Intelligence**: We integrated **Apple Intelligence** (FoundationModels) to securely generate deeply personal check-in messages on-device, preserving full user privacy. If Apple Intelligence isn't available, it falls back to a locally hosted Ollama model or a curated message library, meaning the app *never* feels broken.
- **The "PerchBrain"**: We built a local JSON memory store that tracks which reminders you dismiss and which ones you respond well to. The AI naturally adapts its personality and check-in frequency to match your specific rhythm.
- **Monetization**: We natively integrated **RevenueCat** using StoreKit 2 to handle our "Perch Pro" subscription, providing seamless access to unlock all personalities, calendar awareness, spoken check-ins, and adaptive memory.

## Challenges we ran into
Building a global, always-on macOS menu bar app that doesn't consume extreme amounts of CPU was tough. We had to rely strictly on event timing and idle timers to determine if the user was focused, rather than polling the system. 
Making the "Notch companion" drop down smoothly without interrupting the user's active window required deep AppKit and `NSPanel` integration to bypass standard window focus rules.

## Accomplishments that we're proud of
1. **The Design**: The notch integration and liquid glass animations feel incredibly premium. We are extremely proud of how non-intrusive and visually stunning the companion feels. 
2. **The "Non-Toxic" AI**: We successfully trained the system prompts to be entirely supportive. Perch will never lecture you or mention productivity metrics. It is strictly a wellbeing companion.

## What we learned
Building a non-intrusive companion requires incredible restraint. We learned how to build complex "delivery rules" in Swift to ensure Perch only talks to you during natural micro-pauses in your work, preventing it from ever being annoying.

**Small on-device models can't be trusted with logic, only with words.** We originally asked the model to decide "is it late right now?" from a timestamp in the prompt. It couldn't, so it told users to go to sleep at 2 PM. The fix that stuck: Swift decides every condition (quiet hours, which habit is behind, what a reply means), and the model only phrases the sentence. Decide in code, speak with AI.

**Never render raw model output in UI.** On-device models ignore formatting instructions often enough that "reply with only 4 options separated by |" comes back as "Sure, here are four short, distinct, natural replies: 1." Every string that reaches a button or a bubble now passes through a sanitizer that strips preambles and numbering, and rejects anything that still doesn't look like a short reply.

**Choices beat conversation for a reminder app.** We shipped a full free-text chat with dictation, then watched it pull us away from the thing Perch is actually for. A person deep in focus doesn't want to compose a message; they want to tap "Just drank some water" and get back to work. Every interaction is now a one-tap choice, answerable right from the notch.

**Ground the companion in real data, not vibes.** Generic supportive lines feel hollow fast. Replies got noticeably better when we fed the model the same numbers the dashboard shows (focus minutes, water, meals, breaks, shower) and told it to praise what's logged and nudge only the one habit that's clearly behind.

## What we sacrificed
**Inline Comments.** We made the deliberate decision to strip out all of our inline code comments right before submission, retaining only the structural `// MARK:` tags and professional `///` docstrings. The tradeoff was losing the historical "why" behind our complex hackathon workarounds, but the outcome is a highly professional, self-documenting architecture that senior engineers can read like a book using the Xcode minimap. It forced us to rely on clean code instead of messy explanations.

**Cloud AI APIs.** We had working OpenAI, Gemini, and Claude integrations. But we removed all of them. This app is a companion, not an AI chatbot. Smarter replies weren't worth asking users for an API key, sending their private moments over the network, or maintaining three providers. To make everything work as expected and get the app to the stable, fast stage it is in now, we had to cut the cloud. Perch runs 100% on device.

**Voice input.** Mic replies and dictation were genuinely cool in demos, but they needed two system permissions, an always-warm speech pipeline, and they were slower than tapping a button. We kept the part that matters (Perch can still speak to you, including in your own Personal Voice) and cut the part that didn't (Perch listening).

**The chatbot.** This was the biggest tradeoff. A companion that chats feels more alive, but Perch's job is to remind you to take care of yourself, not to hold a conversation. By removing the chatbot, we ensured the app remains a true wellbeing companion rather than a distraction. Saying no to the chatbot and the API is what allowed us to get to this refined stage.

## What's next for Perch
We plan to release Perch on the Mac App Store officially! We want to expand the PerchBrain to sync securely via iCloud so your companion remembers your habits across multiple Macs.

---
*I built this for you, and I hope you take care of yourself now, future founder.*
