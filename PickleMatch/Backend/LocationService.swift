import CoreLocation
import Foundation

/// Requests a single coarse foreground location for nearby discovery. Match Point
/// never tracks in the background and never exposes exact coordinates to peers.
@MainActor
final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    enum State: Equatable {
        case idle
        case requesting
        case available
        case denied
        case restricted
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        updateState(for: manager.authorizationStatus)
    }

    func requestWhenInUseAccess() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .requesting
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestCurrentLocation()
        case .denied:
            state = .denied
        case .restricted:
            state = .restricted
        @unknown default:
            state = .failed("Location authorization is unavailable.")
        }
    }

    func requestCurrentLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            state = .failed("Location Services are turned off.")
            return
        }
        guard [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) else {
            requestWhenInUseAccess()
            return
        }
        state = .requesting
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateState(for: manager.authorizationStatus)
        if [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) {
            requestCurrentLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations
            .filter({ $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 300 })
            .min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }) else {
            state = .failed("A current location could not be determined.")
            return
        }
        location = latest
        state = .available
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .denied {
            updateState(for: manager.authorizationStatus)
        } else {
            state = .failed("Location is temporarily unavailable. Please try again.")
        }
    }

    private func updateState(for authorization: CLAuthorizationStatus) {
        switch authorization {
        case .notDetermined: state = .idle
        case .authorizedAlways, .authorizedWhenInUse:
            state = location == nil ? .idle : .available
        case .denied: state = .denied
        case .restricted: state = .restricted
        @unknown default: state = .failed("Location authorization is unavailable.")
        }
    }
}
