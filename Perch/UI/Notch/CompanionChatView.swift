import SwiftUI


struct CompanionChatView: View {
    let coordinator: CompanionCoordinator

    private var chat: CompanionChatService { coordinator.chat }
    private var accent: [Color] { coordinator.accentColors }

    var body: some View {
        VStack(spacing: 10) {
            header
            messageList
        }
    }


    private var header: some View {
        let metrics = coordinator.metrics
        return HStack(spacing: 0) {
            HStack(spacing: 8) {
                CompanionFaceView(state: chat.isThinking ? .thinking : chat.currentEmotion, accent: accent, size: 22)
                Text(coordinator.companionName)
                    .font(.perchRounded(12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if metrics.hasNotch {
                Color.clear.frame(width: metrics.notchWidth + 12, height: 1)
            }
            HStack(spacing: 6) {
                Button { chat.clear(); chat.openIfNeeded() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(IconPillButtonStyle())
                .help("Start over")
                Button { coordinator.hide() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(IconPillButtonStyle())
                .keyboardShortcut(.cancelAction)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: metrics.hasNotch ? max(metrics.topInset - 6, 26) : 28)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(chat.messages) { message in
                        row(for: message)
                            .id(message.id)
                    }
                    if chat.isThinking {
                        thinkingRow
                            .id("thinking")
                    }
                    if !chat.isThinking {
                        suggestionChips
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 2)
            }
            .defaultScrollAnchor(.bottom)
            .scrollIndicators(.never)
            .frame(maxHeight: .infinity)
            .onChange(of: chat.messages.count) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: chat.isThinking) {
                if chat.isThinking {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    private func row(for message: CompanionChatService.ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 36) }
            Text(message.text)
                .font(.perchRounded(12.5))
                .foregroundStyle(message.isUser ? .black.opacity(0.85) : .white.opacity(0.92))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    message.isUser
                        ? AnyShapeStyle(PerchStyle.accentGradient(accent))
                        : AnyShapeStyle(.white.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .textSelection(.enabled)
            if !message.isUser { Spacer(minLength: 36) }
        }
    }

    private var thinkingRow: some View {
        HStack {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        thinkingDot(index: index, t: t)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            Spacer()
        }
    }

    private var suggestionChips: some View {
        let chips = chat.suggestions.isEmpty ? ["I feel burned out", "I can't focus", "I shipped something today", "I don't know what's next"] : chat.suggestions


        var rows: [[String]] = []
        for i in stride(from: 0, to: chips.count, by: 2) {
            let end = min(i + 2, chips.count)
            rows.append(Array(chips[i..<end]))
        }

        return VStack(spacing: 6) {
            Text("Pick what's closest to how you feel.")
                .font(.perchRounded(10.5))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 2)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, prompt in
                        Button(prompt) { chat.send(prompt) }
                            .buttonStyle(GhostPillButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private func thinkingDot(index: Int, t: TimeInterval) -> some View {
        let wave: Double = 0.5 + 0.5 * sin(t * 4 + Double(index) * 0.9)
        let opacity: Double = 0.35 + 0.4 * wave
        return Circle()
            .fill(.white.opacity(opacity))
            .frame(width: 5, height: 5)
    }

}
