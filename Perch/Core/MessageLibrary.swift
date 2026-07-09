import Foundation

/// Curated companion lines. These are the guaranteed voice of Perch:
enum MessageLibrary {

    static func variants(kind: ReminderKind, personality: Personality) -> [String] {
        switch (kind, personality) {

        // MARK: Water
        case (.water, .mother): return [
            "Sweetheart, you haven't had water in a while. Drink first, the code can wait a minute.",
            "{name}, have some water please. I worry when you forget."]
        case (.water, .homie): return [
            "Yo {name}, hydration check. Grab some water real quick, then keep cooking.",
            "Bro. Water. Now. Your brain runs on it, trust."]
        case (.water, .professional): return [
            "Quick note: no water logged in a while. A glass now will keep your focus sharp.",
            "Hydration reminder. A short water break is recommended before your next block."]
        case (.water, .mentor): return [
            "A small thing done consistently: drink some water, {name}. It keeps the mind clear.",
            "Pause. Water. The work will still be here in ninety seconds."]
        case (.water, .coach): return [
            "Hydration rep, {name}! One glass, then back in the game.",
            "Athletes hydrate. Builders too. Quick water break, let's go."]
        case (.water, .playful): return [
            "Beep beep. Your internal plants need watering, {name}.",
            "Fun fact: you are mostly water. Top yourself up a little?"]

        // MARK: Stretch
        case (.stretch, .mother): return [
            "Sweetheart, you've been sitting for {duration}. Stand up and stretch for me, please.",
            "{name}, your back will thank you later. One minute of stretching, okay?"]
        case (.stretch, .homie): return [
            "Bro, you've been locked in for {duration}. Stretch first, then cook again.",
            "{name}, quick stretch break. Can't ship greatness with a stiff neck."]
        case (.stretch, .professional): return [
            "You have been focused for {duration}. A short stretch break is recommended.",
            "Long session detected: {duration}. Consider standing and stretching briefly."]
        case (.stretch, .mentor): return [
            "It's been {duration} of deep work. Stand, breathe, stretch. Then return with fresh eyes.",
            "{name}, the body carries the mind. Give it a minute of movement."]
        case (.stretch, .coach): return [
            "{duration} of focus, nice endurance {name}! Now a mobility minute. Stand up, reach tall.",
            "Time out! Stretch those shoulders. Recovery is part of the program."]
        case (.stretch, .playful): return [
            "You've been statue mode for {duration}. Time to do the human noodle dance.",
            "Stretch o'clock, {name}. Arms up! Pretend you just won something."]

        // MARK: Eyes
        case (.eyes, .mother): return [
            "Rest your eyes for a moment, sweetheart. Look far away, blink a little.",
            "{name}, your eyes have been working hard. Look out the window for twenty seconds."]
        case (.eyes, .homie): return [
            "Eyes check, {name}. Stare at something far away for a sec, screens are brutal.",
            "Give your eyes a breather bro. Twenty seconds, something 20 feet away."]
        case (.eyes, .professional): return [
            "Eye strain prevention: focus on a distant object for about twenty seconds.",
            "Screen time is adding up. A brief distance gaze will reset your eyes."]
        case (.eyes, .mentor): return [
            "Let your gaze travel somewhere far for a moment. The eyes need horizons too.",
            "Twenty seconds of distance, {name}. Small habits protect long careers."]
        case (.eyes, .coach): return [
            "Eye reset rep! Twenty seconds, far focus. Protect the equipment, {name}.",
            "Blink break! Look far, breathe once, back in."]
        case (.eyes, .playful): return [
            "Your eyeballs formally request a vacation. A tiny one. Twenty seconds, far away.",
            "Quick! Look at the farthest thing you can find. It's a game. You win by blinking."]

        // MARK: Posture
        case (.posture, .mother): return [
            "Sweetheart, sit up straight for me. Shoulders back, deep breath.",
            "{name}, check your posture please. You'll feel better right away."]
        case (.posture, .homie): return [
            "Posture check {name}. Unfold yourself, you're doing the shrimp thing again.",
            "Sit up bro. Future you says thanks."]
        case (.posture, .professional): return [
            "Posture check: shoulders relaxed, back supported, screen at eye level.",
            "A brief posture reset now will prevent fatigue later."]
        case (.posture, .mentor): return [
            "Notice how you're sitting, {name}. Straighten gently. Alignment is quiet strength.",
            "A tall spine, a calm breath. Continue."]
        case (.posture, .coach): return [
            "Form check, {name}! Chest up, shoulders back. Good form, good output.",
            "Reset that stance! Even sitting is a sport if you do it right."]
        case (.posture, .playful): return [
            "Croissant detected in your chair. Please return to human shape, {name}.",
            "Posture patrol! Straighten up before you evolve into a question mark."]

        // MARK: Walk
        case (.walk, .mother): return [
            "You've been inside this screen for {duration}, sweetheart. A short walk would be so good for you.",
            "{name}, stretch your legs a little. Even just around the room, please."]
        case (.walk, .homie): return [
            "Big session, {name}. {duration} straight. Take a lap, get some air, come back sharper.",
            "Bro, five minute walk. The best ideas show up when you step away."]
        case (.walk, .professional): return [
            "You have been at your desk for {duration}. A five minute walk is recommended.",
            "Extended session: {duration}. A brief walk will restore focus and circulation."]
        case (.walk, .mentor): return [
            "{duration} of sitting, {name}. Walking is thinking. Give yourself five minutes of it.",
            "Step away briefly. Distance from the problem is often the fastest path through it."]
        case (.walk, .coach): return [
            "Cardio micro session! Five minute walk, {name}. Movement feeds momentum.",
            "{duration} on the bench, time to move! Quick lap, then we go again."]
        case (.walk, .playful): return [
            "Your legs just filed a missing person report. Take them for a walk?",
            "Adventure time, {name}! A legendary five minute quest to Outside."]

        // MARK: Meal
        case (.meal, .mother): return [
            "Sweetheart, it's {meal} time. Have you eaten? Please don't skip it for work.",
            "You skipped {meal} around this time yesterday, {name}. Please eat something today, promise?"]
        case (.meal, .homie): return [
            "{name}, {meal} time bro. Feed the machine or the machine stops cooking.",
            "You dodged {meal} yesterday. Not today bro. Go eat, I'll hold your spot."]
        case (.meal, .professional): return [
            "It's around your usual {meal} time. Taking it now will keep your afternoon steady.",
            "Reminder: {meal} was skipped yesterday. A proper break today is strongly recommended."]
        case (.meal, .mentor): return [
            "It's {meal} time, {name}. Fuel is part of the work, not a break from it.",
            "Yesterday {meal} slipped past you. Today, let it anchor your day instead."]
        case (.meal, .coach): return [
            "Fuel window open, {name}! {meal} time. You can't out-train an empty tank.",
            "Nutrition is training too. Go get {meal}, champ."]
        case (.meal, .playful): return [
            "Your stomach called. It said something dramatic about {meal}. Better go check.",
            "{meal} quest available! Reward: energy, joy, not being hangry."]

        // MARK: Overwork
        case (.overwork, .mother): return [
            "Sweetheart, you've been working for {duration} without a real break. Please pause, for me.",
            "{name}, this is a long one. {duration} already. Rest a little, the work will keep."]
        case (.overwork, .homie): return [
            "Bro. {duration} straight. Certified grinder, but even legends take five. Breathe.",
            "{name}, you've been locked in {duration}. Respect. Now step off for a few, seriously."]
        case (.overwork, .professional): return [
            "You have worked for {duration} without a meaningful break. A recovery pause is advised.",
            "Long focus block: {duration}. Sustained output requires a reset. Please take one."]
        case (.overwork, .mentor): return [
            "{duration} of continuous work, {name}. The craft rewards rhythm, not exhaustion.",
            "You've gone {duration} deep. Surface for air. Marathons are run in segments."]
        case (.overwork, .coach): return [
            "{duration} straight, {name}! Massive effort. Now the pro move: real recovery, right now.",
            "Overtime alert! {duration} in. Champions rest on purpose. Take the break."]
        case (.overwork, .playful): return [
            "You've been at this {duration}. Even video game characters get loading screens.",
            "{duration}?! Okay hero, pause the montage. Snacks and air, then glory."]

        // MARK: Wind down
        case (.windDown, .mother): return [
            "It's past your work hours, sweetheart. Start closing things up, home matters too.",
            "{name}, the day was enough. Wrap up soon and rest, please."]
        case (.windDown, .homie): return [
            "Yo {name}, shift's over. Commit, push, shut it down. Tomorrow you runs it back.",
            "Past quitting time bro. Save your progress. Life's the main quest too."]
        case (.windDown, .professional): return [
            "You are past your set work hours. Consider wrapping up your current task.",
            "End of day reached. A clean stop now protects tomorrow's performance."]
        case (.windDown, .mentor): return [
            "The workday you designed has ended, {name}. Honor it. Stopping is a skill.",
            "Done is a decision. Make it, and let the evening do its quiet work."]
        case (.windDown, .coach): return [
            "Final whistle, {name}! Great session. Now cool down and log off strong.",
            "Training's over for today. Recovery mode: on. That's an order, champ."]
        case (.windDown, .playful): return [
            "The sun clocked out and honestly, so should you, {name}.",
            "Closing time in the goblin cave. Save file, stretch, touch some evening."]

        // MARK: Sleep
        case (.sleep, .mother): return [
            "Sweetheart, it's late. Sleep now please. You did enough today, I mean it.",
            "{name}, tomorrow needs you rested. Bed soon, okay?"]
        case (.sleep, .homie): return [
            "Bro it's late late. Sleep is the ultimate performance hack. Go get it.",
            "{name}, log off. The grind respects those who sleep."]
        case (.sleep, .professional): return [
            "It is past your quiet hours. Sleep will do more for tomorrow than this last task.",
            "Late night detected. Recommend ending the session and resting."]
        case (.sleep, .mentor): return [
            "You did enough today, {name}. Rest matters too. Let sleep finish the work.",
            "The night shift belongs to your dreams, not your deadlines."]
        case (.sleep, .coach): return [
            "Recovery is where gains happen, {name}. Lights out soon, that's the play.",
            "Overtime's over. Sleep is tomorrow's pre-game. Go."]
        case (.sleep, .playful): return [
            "Even your computer wants to sleep. Race you to bed, {name}.",
            "It's past midnight-ish. Wizards need mana. Go recharge yours."]

        // MARK: Meeting prep
        case (.meetingPrep, .mother): return [
            "Sweetheart, {event} starts in {mins} minutes. Get ready now, and bring water.",
            "{name}, {event} is coming up in {mins} minutes. Take a breath and prepare."]
        case (.meetingPrep, .homie): return [
            "Heads up {name}, {event} in {mins} minutes. Wrap this thought and slide in prepared.",
            "{event} in {mins}, bro. Quick prep now saves the scramble later."]
        case (.meetingPrep, .professional): return [
            "{event} begins in {mins} minutes. Now is a good moment to prepare.",
            "Upcoming: {event} in {mins} minutes. Consider reviewing your notes."]
        case (.meetingPrep, .mentor): return [
            "{event} arrives in {mins} minutes, {name}. Enter it calm, not rushed.",
            "A pause before {event} will serve you better than one more minute of work."]
        case (.meetingPrep, .coach): return [
            "Game time in {mins} minutes: {event}. Head up, notes ready, {name}!",
            "{event} in {mins}. Warm up now, show up sharp."]
        case (.meetingPrep, .playful): return [
            "Plot twist in {mins} minutes: {event}. Time to look convincingly prepared.",
            "{event} approaches! You have {mins} minutes to become extremely professional."]

        // MARK: Meeting recovery
        case (.meetingRecovery, .mother): return [
            "That was a long meeting, sweetheart. Drink water and breathe before the next thing.",
            "Meeting's done, {name}. Rest your voice and your mind for a moment."]
        case (.meetingRecovery, .homie): return [
            "Survived the meeting, {name}. Take five before you dive back in.",
            "Meeting done bro. Shake it off, reset, then back to building."]
        case (.meetingRecovery, .professional): return [
            "Your meeting has ended. A short reset before resuming deep work is recommended.",
            "Meeting complete. Two quiet minutes now will improve your next block."]
        case (.meetingRecovery, .mentor): return [
            "Meetings spend a different energy, {name}. Refill it before returning to the craft.",
            "The meeting is over. Let it fully end before the next thing begins."]
        case (.meetingRecovery, .coach): return [
            "Round complete, {name}! Quick recovery: water, stand, breathe. Then next play.",
            "Meeting done. Active recovery time, two minutes."]
        case (.meetingRecovery, .playful): return [
            "You escaped the meeting! Celebrate with water and thirty seconds of staring at nothing.",
            "Meeting over. Social battery at low percent. Please recharge before use."]

        // MARK: Routine
        case (.routine, .mother): return [
            "Sweetheart, gentle reminder: {routine}.",
            "{name}, it's time for {routine}. You asked me to remind you."]
        case (.routine, .homie): return [
            "Yo {name}, you told me to remind you: {routine}. Handle it.",
            "Reminder from past you, bro: {routine}."]
        case (.routine, .professional): return [
            "Scheduled reminder: {routine}.",
            "As requested: it's time for {routine}."]
        case (.routine, .mentor): return [
            "You made a promise to yourself: {routine}. Keep it.",
            "It's time for {routine}, {name}. Rituals build the person."]
        case (.routine, .coach): return [
            "Routine rep, {name}: {routine}. Consistency wins.",
            "Time for {routine}! Small habits, big season."]
        case (.routine, .playful): return [
            "Ding ding! Past you left a note: {routine}.",
            "Scheduled whimsy: {routine}. Off you go, {name}."]

        // MARK: Status
        case (.status, .mother): return [
            "You've been focused for {duration}, sweetheart. How are you feeling right now?",
            "{duration} of good work so far, {name}. Is there anything you need from me?"]
        case (.status, .homie): return [
            "You're {duration} deep and cruising, {name}. How's it going in there?",
            "{duration} locked in, bro. You good, or you need a breather?"]
        case (.status, .professional): return [
            "You're at {duration} of focus. Is everything going smoothly?",
            "Current session: {duration}. Anything you'd like me to help with?"]
        case (.status, .mentor): return [
            "{duration} of steady work, {name}. How is your energy holding up?",
            "The session flows well at {duration}. Are you still in a good rhythm?"]
        case (.status, .coach): return [
            "{duration} on the clock and looking strong, {name}! How are you feeling?",
            "Solid pace, {duration} in! Got enough in the tank, or need a break?"]
        case (.status, .playful): return [
            "{duration} of suspiciously excellent focus, {name}. How's the brain holding up?",
            "You've been at it {duration}. Still having fun, or should we take five?"]

        // MARK: Session start
        case (.sessionStart, .mother): return [
            "There you are, sweetheart. Starting another session? Want me to watch the clock for you?",
            "Good to see you working, {name}. Have you eaten and had water first?"]
        case (.sessionStart, .homie): return [
            "Yo {name}, locking in? Want me to keep you honest on breaks?",
            "New session, let's cook. Should I ping you when it's water time?"]
        case (.sessionStart, .professional): return [
            "Starting a focus session? I can watch your pace and check in. Sound good?",
            "You're in focus, {name}. Would you like me to remind you about breaks?"]
        case (.sessionStart, .mentor): return [
            "A fresh block begins, {name}. What's the one thing you want to finish?",
            "Back to the craft. Shall I guard the pace so you don't have to?"]
        case (.sessionStart, .coach): return [
            "Session's live, {name}! Ready to lock in? I'll call the recovery breaks.",
            "Game on! Want me to keep you on a solid work-rest rhythm today?"]
        case (.sessionStart, .playful): return [
            "A wild focus session appears! Want a tiny guardian on break duty, {name}?",
            "Guardian mode ready. Should I nudge you when it's time to move?"]

        // MARK: Welcome
        case (.welcome, .mother): return [
            "Hello sweetheart. I'm here now. Work well, and I'll make sure you take care of yourself too."]
        case (.welcome, .homie): return [
            "Yo {name}! I'm perched. You build, I'll watch your six. Let's cook."]
        case (.welcome, .professional): return [
            "Setup complete. I will monitor your session quietly and check in at the right moments."]
        case (.welcome, .mentor): return [
            "I'm with you now, {name}. Build with intention. I'll guard the pace."]
        case (.welcome, .coach): return [
            "Team {name} is live! You focus on the win, I'll manage the recovery plan."]
        case (.welcome, .playful): return [
            "A tiny guardian has appeared above your screen! Hi {name}. Let's do great things, gently."]
        }
    }

    static func confirmations(response: CheckInResponse, personality: Personality) -> [String] {
        switch response {
        case .done, .timerCompleted:
            switch personality {
            case .mother: return ["Good, sweetheart. Thank you.", "That's my {name}. Back to it."]
            case .homie: return ["That's what I'm talking about.", "Easy. Back to cooking, bro."]
            case .professional: return ["Noted. Resuming focus.", "Logged. Well done."]
            case .mentor: return ["Well kept, {name}.", "Good. Small acts, long careers."]
            case .coach: return ["Rep counted! Nice.", "That's the discipline. Go."]
            case .playful: return ["Achievement unlocked!", "Gold star. Massive one."]
            }
        case .snoozed:
            switch personality {
            case .mother: return ["Okay sweetheart, but I'll come back. Promise me."]
            case .homie: return ["Bet. I'll circle back in a few."]
            case .professional: return ["Understood. I'll remind you shortly."]
            case .mentor: return ["Alright. I'll return when the moment is better."]
            case .coach: return ["Copy that. Short delay, then we go."]
            case .playful: return ["Fine, but I'm setting a tiny dramatic timer."]
            }
        case .ignored, .timedOut:
            switch personality {
            case .mother: return ["Okay, I'll let you focus. Take care, okay?"]
            case .homie: return ["All good. I'll catch you later."]
            case .professional: return ["Dismissed. I'll stay out of the way."]
            case .mentor: return ["Understood. The work calls. I'll be near."]
            case .coach: return ["Roger. Back to the game."]
            case .playful: return ["Vanishing gracefully. Poof."]
            }
        }
    }

    static func sample(personality: Personality) -> String {
        switch personality {
        case .mother: "Sweetheart, you've been working too long. Please drink water first."
        case .homie: "Bro, you've been locked in for 3 hours. Stretch first, then cook again."
        case .professional: "You have worked for 3 hours. A short recovery break is recommended."
        case .mentor: "Three hours of deep work. Surface for air, the craft rewards rhythm."
        case .coach: "Three hours straight, champ! Now the pro move: real recovery."
        case .playful: "Three hours?! Even game characters get loading screens. Pause the montage."
        }
    }
}
