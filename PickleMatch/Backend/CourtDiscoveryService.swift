import CoreLocation
import Foundation
import MapKit

/// Uses Apple Maps so beta testers see real facilities near their current
/// location without shipping another API key in the app.
actor CourtDiscoveryService {
    func discover(sport: Sport, near location: CLLocation, radiusMiles: Double = 25) async throws -> [DiscoveredCourt] {
        guard sport.isAvailableInBeta else { return [] }
        let meters = min(max(radiusMiles, 1), 50) * 1_609.344
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: meters * 2,
            longitudinalMeters: meters * 2
        )
        let queries = sport == .pickleball
            ? ["pickleball court", "pickleball club"]
            : ["badminton court", "badminton club"]

        var unique: [String: DiscoveredCourt] = [:]
        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = [.pointOfInterest, .address]
            let response = try await MKLocalSearch(request: request).start()
            for item in response.mapItems {
                let coordinate = item.placemark.coordinate
                let candidateLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                guard candidateLocation.distance(from: location) <= meters,
                      let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { continue }
                let key = String(format: "%@|%.5f|%.5f", name.lowercased(), coordinate.latitude, coordinate.longitude)
                let addressParts = [item.placemark.subThoroughfare, item.placemark.thoroughfare]
                    .compactMap { $0 }.filter { !$0.isEmpty }
                unique[key] = DiscoveredCourt(
                    externalID: key,
                    name: name,
                    address: addressParts.joined(separator: " "),
                    city: item.placemark.locality ?? "",
                    region: item.placemark.administrativeArea ?? "",
                    postalCode: item.placemark.postalCode ?? "",
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    websiteURL: item.url?.absoluteString,
                    phone: item.phoneNumber,
                    sports: [sport]
                )
            }
        }
        return unique.values.sorted {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: location) <
            CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: location)
        }
    }
}
