import CoreLocation
import WeatherKit
import Observation

enum SkyCondition {
    case clear
    case rain
    case thunderstorm
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
