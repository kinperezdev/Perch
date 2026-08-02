import CoreLocation
import WeatherKit
import Observation
import SwiftUI

enum SkyCondition {
    case clear
    case rain
    case thunderstorm
}

/// The eight named phases a real sky moves through in a day, each carrying a
/// single saturated color used as a glow at the top of an otherwise-constant
/// dark background, rather than tinting the whole view.
enum TimeOfDay {
    case night
    case preDawn
    case sunrise
    case morning
    case midday
    case goldenHour
    case sunset
    case twilight

    var topTint: Color {
        switch self {
        case .night: Color(hex: 0x121B3D)
        case .preDawn: Color(hex: 0x1B2A52)
        case .sunrise: Color(hex: 0xE85C4A)
        case .morning: Color(hex: 0x3D8FE0)
        case .midday: Color(hex: 0x4FC3F7)
        case .goldenHour: Color(hex: 0xEBA93D)
        case .sunset: Color(hex: 0xE0431F)
        case .twilight: Color(hex: 0x1C2B4A)
        }
    }

    fileprivate static func at(_ date: Date) -> TimeOfDay {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        switch minutes {
        case 300..<360: return .preDawn
        case 360..<450: return .sunrise
        case 450..<600: return .morning
        case 600..<900: return .midday
        case 900..<1050: return .goldenHour
        case 1050..<1110: return .sunset
        case 1110..<1200: return .twilight
        default: return .night
        }
    }
}

/// Fetches local daylight state and a simplified weather condition once per
/// dashboard appearance, so the background can show stars at night, clouds and
/// birds by day, or rain/thunder when that's what's actually happening outside.
/// Fails silently to the clear-day default on any error (no entitlement, denied
/// location, offline), the dashboard should never break because the sky can't load.
@MainActor
@Observable
final class SkyService: NSObject {
    private(set) var isNight = SkyService.isNightByClock()
    private(set) var condition: SkyCondition = .clear

    var timeOfDay: TimeOfDay { TimeOfDay.at(Date()) }
    var topTint: Color { timeOfDay.topTint }

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var continuation: CheckedContinuation<CLLocation, Error>?
    @ObservationIgnored private var didFetch = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func refreshIfNeeded() {
        guard !didFetch else { return }
        didFetch = true
        Task {
            do {
                let location = try await currentLocation()
                let weather = try await WeatherService.shared.weather(for: location)
                isNight = !weather.currentWeather.isDaylight
                condition = Self.mapCondition(weather.currentWeather.condition)
            } catch {
                didFetch = false
            }
        }
    }

    private func currentLocation() async throws -> CLLocation {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            throw CLError(.denied)
        default:
            break
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            locationManager.requestLocation()
        }
    }

    /// Reasonable night/day guess from the device clock alone, used before
    /// WeatherKit's more precise sunrise/sunset-based answer arrives (or if it
    /// never arrives, no entitlement, no location, offline).
    private static func isNightByClock(at date: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 19 || hour < 6
    }

    private static func mapCondition(_ condition: WeatherKit.WeatherCondition) -> SkyCondition {
        switch condition {
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return .thunderstorm
        case .rain, .heavyRain, .drizzle, .sunShowers, .freezingRain, .freezingDrizzle:
            return .rain
        default:
            return .clear
        }
    }
}

extension SkyService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: CLError(.denied))
            continuation = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
