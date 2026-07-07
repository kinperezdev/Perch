#!/bin/bash
set -e

cd /Users/kinclarkperez/Desktop/Swift/Macoshackathon

git init
git remote add origin https://github.com/kinperezdev/Perchify.git || true

commit_chunk() {
    message="$1"
    shift
    for file in "$@"; do
        if [ -e "$file" ]; then
            git add "$file"
        fi
    done
    git commit -m "$message" || echo "Nothing to commit for $message"
}

commit_chunk "Initial commit: Project setup and base configuration" \
    Perch.xcodeproj \
    Perch/App/PerchApp.swift \
    Perch/App/AppDelegate.swift \
    Perch/App/AppContainer.swift \
    Config \
    Perch/Assets.xcassets \
    Perch/Preview\ Content

commit_chunk "Add core data models, preferences, and memory store" \
    Perch/Core/Models.swift \
    Perch/Core/PreferencesStore.swift \
    Perch/Core/HabitMemoryStore.swift \
    Perch/Core/Keychain.swift

commit_chunk "Implement custom Design System and window presentation logic" \
    Perch/UI/DesignSystem.swift \
    Perch/App/WindowPresenter.swift \
    Perch/UI/Paywall \
    Perch/UI/Weekly

commit_chunk "Build PerchBrain and AI intelligence engines" \
    Perch/Core/PerchBrain.swift \
    Perch/Core/CompanionIntelligence.swift \
    Perch/Core/OnlineIntelligence.swift \
    Perch/Core/PersonalityEngine.swift \
    Perch/Core/MessageLibrary.swift

commit_chunk "Create user Dashboard, Settings, and Onboarding views" \
    Perch/UI/Dashboard \
    Perch/UI/Settings \
    Perch/UI/Onboarding

commit_chunk "Integrate Voice services and Companion Chat Engine" \
    Perch/Core/VoiceService.swift \
    Perch/Core/CompanionChatService.swift \
    Perch/UI/Notch/CompanionChatView.swift \
    Perch/UI/Notch/CompanionFaceView.swift

commit_chunk "Add Notch pop-down UI and Menu Bar integration" \
    Perch/UI/Notch/NotchCompanionView.swift \
    Perch/UI/Notch/NotchPanelController.swift \
    Perch/UI/MenuBar/MenuBarContentView.swift \
    Perch/Core/CompanionCoordinator.swift

commit_chunk "Implement focus tracking, calendar awareness, and background reminder engines" \
    Perch/Core/CalendarAwarenessService.swift \
    Perch/Core/FocusSessionTracker.swift \
    Perch/Core/NotificationService.swift \
    Perch/Core/ReminderEngine.swift \
    Perch/Core/QuickAnswerShortcutManager.swift \
    Perch/Core/SubscriptionManager.swift \
    Perch/App/PerchIntents.swift

git add .
git commit -m "Final polish and app enhancements" || echo "No leftover files"

git branch -M main

echo "All commits created successfully!"

