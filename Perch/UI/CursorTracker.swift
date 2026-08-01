import SwiftUI

/// Live cursor position, in the coordinate space of whichever window is tracking it,
/// so `CompanionFaceView` instances in that window can look toward the cursor.
@MainActor
@Observable
final class CursorTracker {
    static let shared = CursorTracker()
    private init() {}

    fileprivate(set) var location: CGPoint?
}

extension View {
    /// Attach to a window's root view so any `CompanionFaceView` inside it looks
    /// toward the cursor while the cursor is within this view's bounds.
    func trackCursorForCompanion() -> some View {
        onContinuousHover(coordinateSpace: .global) { phase in
            switch phase {
            case .active(let point):
                CursorTracker.shared.location = point
            case .ended:
                CursorTracker.shared.location = nil
            }
        }
    }
}
