import EventKit
import Foundation
import Observation

/// Reads upcoming events, with permission, so check ins can respect
@MainActor
@Observable
final class CalendarAwarenessService {

    struct EventInfo: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
    }

    private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    private(set) var upcoming: [EventInfo] = []

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    var isAuthorized: Bool { authorization == .fullAccess }

    func requestAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        authorization = EKEventStore.authorizationStatus(for: .event)
        if granted { start() }
        return granted
    }

    func start() {
        guard isAuthorized, pollTask == nil else { return }
        refresh()
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                await MainActor.run { self?.refresh() }
            }
        }
    }

    func refresh() {
        guard isAuthorized else { return }
        let now = Date()
        guard let horizon = Calendar.current.date(byAdding: .hour, value: 24, to: now) else { return }
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-3 * 3600),
            end: horizon,
            calendars: nil
        )
        upcoming = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .map {
                EventInfo(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title ?? "Meeting",
                    start: $0.startDate,
                    end: $0.endDate
                )
            }
            .sorted { $0.start < $1.start }
    }

    // MARK: Queries

    func nextEvent(startingWithinMinutes minutes: Int, at date: Date = Date()) -> EventInfo? {
        upcoming.first {
            $0.start > date && $0.start.timeIntervalSince(date) <= Double(minutes) * 60
        }
    }

    func currentEvent(at date: Date = Date()) -> EventInfo? {
        upcoming.first { $0.start <= date && date < $0.end }
    }

    func recentlyEndedMeeting(withinMinutes: Int, minimumDurationMinutes: Int, at date: Date = Date()) -> EventInfo? {
        upcoming.first {
            $0.end <= date
                && date.timeIntervalSince($0.end) <= Double(withinMinutes) * 60
                && $0.end.timeIntervalSince($0.start) >= Double(minimumDurationMinutes) * 60
        }
    }
}
