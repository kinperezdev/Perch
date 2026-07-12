import Foundation

enum MessageLibrary {

    static func variants(kind: ReminderKind, personality: Personality) -> [String] {
        switch (kind, personality) {

        // MARK: Water
        case (.water, .mother): return [
            "Sweetheart, have you had any water lately? Please drink a glass, the code can wait.",
            "{name}, did you remember to drink water? I worry when you forget."]
        case (.water, .homie): return [
            "Yo {name}, hydration check—have you drank any water? Grab some real quick.",
            "Bro, are you drinking water? Your brain runs on it, trust."]
        case (.water, .professional): return [
            "Have you had water recently? A glass now will keep your focus sharp.",
            "Hydration reminder. Did you take a short water break before your next block?"]
        case (.water, .mentor): return [
            "Have you drank any water, {name}? It keeps the mind clear.",
            "Did you pause for water? The work will still be here in ninety seconds."]
        case (.water, .coach): return [
            "Did you hit your hydration rep, {name}? One glass, then back in the game.",
            "Athletes hydrate, builders too. Did you take a quick water break?"]
        case (.water, .playful): return [
            "Beep beep. Did you water your internal plants today, {name}?",
            "Fun fact: you are mostly water. Want to top yourself up a little?"]

        // MARK: Stretch
        case (.stretch, .mother): return [
            "Sweetheart, you've been sitting for {duration}. Could you stand up and stretch for me?",
            "{name}, your back will thank you later. Did you take a minute to stretch?"]
        case (.stretch, .homie): return [
            "Bro, you've been locked in for {duration}. Did you stretch yet?",
            "{name}, how about a quick stretch break? Can't ship greatness with a stiff neck."]
        case (.stretch, .professional): return [
            "You have been focused for {duration}. Have you taken a short stretch break?",
            "Long session detected: {duration}. Would you like to stand and stretch briefly?"]
        case (.stretch, .mentor): return [
            "It's been {duration} of deep work. Did you stand, breathe, and stretch?",
            "{name}, the body carries the mind. Have you given it a minute of movement?"]
        case (.stretch, .coach): return [
            "{duration} of focus! Have you done your mobility minute? Stand up, reach tall.",
            "Time out! Did you stretch those shoulders? Recovery is part of the program."]
        case (.stretch, .playful): return [
            "You've been statue mode for {duration}. Are you ready to do the human noodle dance?",
            "Stretch o'clock, {name}. Arms up! Have you pretended you just won something yet?"]

        // MARK: Eyes
        case (.eyes, .mother): return [
            "Have you rested your eyes, sweetheart? Look far away, blink a little.",
            "{name}, your eyes have been working hard. Did you look out the window today?"]
        case (.eyes, .homie): return [
            "Eyes check, {name}. Did you stare at something far away for a sec?",
            "Are you giving your eyes a breather, bro? Twenty seconds, something 20 feet away."]
        case (.eyes, .professional): return [
            "Have you focused on a distant object recently to prevent eye strain?",
            "Screen time is adding up. Did you take a brief distance gaze to reset your eyes?"]
        case (.eyes, .mentor): return [
            "Have you let your gaze travel somewhere far? The eyes need horizons too.",
            "Did you take twenty seconds of distance, {name}? Small habits protect long careers."]
        case (.eyes, .coach): return [
            "Did you do your eye reset rep? Twenty seconds, far focus. Protect the equipment.",
            "Blink break! Did you look far and breathe before going back in?"]
        case (.eyes, .playful): return [
            "Your eyeballs formally request a vacation. Did you give them twenty seconds far away?",
            "Quick! Have you looked at the farthest thing you can find?"]

        // MARK: Posture
        case (.posture, .mother): return [
            "Sweetheart, are you sitting up straight? Shoulders back, deep breath.",
            "{name}, did you check your posture? You'll feel better right away."]
        case (.posture, .homie): return [
            "Posture check {name}. Are you doing the shrimp thing again?",
            "Are you sitting up, bro? Future you will say thanks."]
        case (.posture, .professional): return [
            "Posture check: are your shoulders relaxed and screen at eye level?",
            "Have you done a brief posture reset? It will prevent fatigue later."]
        case (.posture, .mentor): return [
            "Have you noticed how you're sitting, {name}? Straighten gently.",
            "Are you keeping a tall spine and a calm breath?"]
        case (.posture, .coach): return [
            "Form check, {name}! Are your chest up and shoulders back?",
            "Did you reset that stance? Even sitting is a sport if you do it right."]
        case (.posture, .playful): return [
            "Croissant detected in your chair. Could you please return to human shape, {name}?",
            "Posture patrol! Are you straightening up before you evolve into a question mark?"]

        // MARK: Walk
        case (.walk, .mother): return [
            "You've been inside this screen for {duration}. Would you like to take a short walk?",
            "{name}, did you stretch your legs today? Even just around the room?"]
        case (.walk, .homie): return [
            "Big session, {name}. {duration} straight. Want to take a lap and get some air?",
            "Bro, how about a short walk? The best ideas show up when you step away."]
        case (.walk, .professional): return [
            "You have been at your desk for {duration}. Would you consider a short walk?",
            "Extended session: {duration}. Did you take a brief walk to restore focus?"]
        case (.walk, .mentor): return [
            "{duration} of sitting, {name}. Have you given yourself a few minutes to walk?",
            "Did you step away briefly? Distance from the problem is often the fastest path through it."]
        case (.walk, .coach): return [
            "Cardio micro session! Have you taken a short walk, {name}?",
            "{duration} on the bench! Want to take a quick lap before we go again?"]
        case (.walk, .playful): return [
            "Your legs just filed a missing person report. Want to take them for a walk?",
            "Adventure time, {name}! Ready for a legendary quick quest to Outside?"]

        // MARK: Meal
        case (.meal, .mother): return [
            "Sweetheart, it's {meal} time. Have you eaten yet?",
            "You skipped {meal} yesterday, {name}. Are you going to eat something today?"]
        case (.meal, .homie): return [
            "{name}, it's {meal} time bro. Did you feed the machine?",
            "You dodged {meal} yesterday. Are you going to go eat now?"]
        case (.meal, .professional): return [
            "It's around your usual {meal} time. Have you taken a break to eat?",
            "Reminder: {meal} was skipped yesterday. Are you taking a proper break today?"]
        case (.meal, .mentor): return [
            "It's {meal} time, {name}. Have you fueled up for the work?",
            "Yesterday {meal} slipped past you. Will you let it anchor your day today?"]
        case (.meal, .coach): return [
            "Fuel window open, {name}! Have you had your {meal}?",
            "Nutrition is training too. Did you go get your {meal}, champ?"]
        case (.meal, .playful): return [
            "Your stomach called. Have you gone to check on your {meal}?",
            "{meal} quest available! Are you ready to claim your energy reward?"]

        // MARK: Shower
        case (.shower, .mother): return [
            "Sweetheart, it's around your usual shower time. Have you taken one yet?",
            "{name}, did you go freshen up for a bit? You'll feel so much better."]
        case (.shower, .homie): return [
            "Bro, shower time. Have you reset the vibes yet?",
            "{name}, did you go rinse off real quick?"]
        case (.shower, .professional): return [
            "It's around your usual shower time. Have you taken a quick reset?",
            "Reminder: this is typically when you shower. Have you taken one today?"]
        case (.shower, .mentor): return [
            "It's shower time, {name}. Have you taken your small reset?",
            "Cleanse and reset. Have you taken your shower yet?"]
        case (.shower, .coach): return [
            "Reset rep, {name}! Did you take your shower time?",
            "Quick reset in the locker room, champ. Have you showered?"]
        case (.shower, .playful): return [
            "Beep boop. Did you complete your hygiene quest and take a shower, {name}?",
            "It's your usual shower o'clock. Are you going to be a fresh, clean legend?"]

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
            "{duration} of good work so far, {name}. How are you holding up?"]
        case (.status, .homie): return [
            "You're {duration} deep and cruising, {name}. How's it going in there?",
            "{duration} locked in, bro. You good, or you need a breather?"]
        case (.status, .professional): return [
            "You're at {duration} of focus. How are you feeling?",
            "Current session: {duration}. How is it going in there?"]
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
            "There you are, sweetheart. Starting another session?",
            "Good to see you working, {name}. Have you eaten and had water first?"]
        case (.sessionStart, .homie): return [
            "Yo {name}, locking in?",
            "New session, let's cook."]
        case (.sessionStart, .professional): return [
            "Starting a focus session?",
            "You're in focus, {name}."]
        case (.sessionStart, .mentor): return [
            "A fresh block begins, {name}. Ready to start?",
            "Back to the craft."]
        case (.sessionStart, .coach): return [
            "Session's live, {name}! Ready to lock in?",
            "Game on! Let's get to work."]
        case (.sessionStart, .playful): return [
            "A wild focus session appears! Ready, {name}?",
            "Guardian mode ready. Starting focus now?"]

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
            case .playful: return ["Got it! Let's keep the streak alive.", "Nailed it! You're crushing it today."]
            }
        case .snoozed:
            switch personality {
            case .mother: return ["Okay sweetheart, but I'll come back. Promise me.", "Alright, but don't make me ask twice, sweetheart."]
            case .homie: return ["Bet. I'll circle back in a few.", "Aight, snoozed. Don't ghost me though."]
            case .professional: return ["Understood. I'll remind you shortly.", "Noted. A follow up is scheduled."]
            case .mentor: return ["Alright. I'll return when the moment is better.", "Fine. Some moments arrive a little later."]
            case .coach: return ["Copy that. Short delay, then we go.", "Snooze logged. We go again shortly."]
            case .playful: return ["Fine, but I'm setting a tiny dramatic timer.", "Snooze accepted. My tiny timer is dramatic but fair."]
            }
        case .ignored, .timedOut:
            switch personality {
            case .mother: return ["Okay, I'll let you focus. Take care, okay?", "Alright, sweetheart. I'll be close by."]
            case .homie: return ["All good. I'll catch you later.", "Say less. I'm around if you need me."]
            case .professional: return ["Dismissed. I'll stay out of the way.", "Understood. Resuming quiet watch."]
            case .mentor: return ["Understood. The work calls. I'll be near.", "As you wish. I'll keep quiet watch."]
            case .coach: return ["Roger. Back to the game.", "Got it. I'll hold the bench."]
            case .playful: return ["Vanishing gracefully. Poof.", "Poof! I'm still here, just very tiny."]
            }
        }
    }

    static func thanksReplies(personality: Personality) -> [String] {
        switch personality {
        case .mother: ["Always, sweetheart. Now take that break soon, okay?", "Anytime, love. Look after yourself."]
        case .homie: ["Got you, bro. Now actually do it.", "Anytime. I got your six."]
        case .professional: ["Of course. Do consider it soon.", "You're welcome. Carry on."]
        case .mentor: ["Of course. Kindness to yourself finishes the work.", "Always. The reminder is part of the craft."]
        case .coach: ["That's my job! Now go take it, {name}.", "Anytime! Recovery is part of the program."]
        case .playful: ["You're welcome! Tiny guardian duties fulfilled.", "Anytime! It's literally my whole job."]
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
