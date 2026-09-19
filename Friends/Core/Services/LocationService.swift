import CoreLocation
import Foundation
import MapKit

/// Ubicacion del dispositivo. Solo `whenInUse`: la app no necesita saber donde
/// estas cuando no la usas. El servidor redondea a una rejilla de ~500 m y nunca
/// devuelve coordenadas de nadie, pero aun asi se pide el permiso con contexto.
@MainActor
@Observable
final class LocationService: NSObject {
    static let shared = LocationService()

    enum Access { case notDetermined, denied, granted }

    private(set) var access: Access = .notDetermined
    private(set) var isUpdating = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer   // no hace falta mas
        refreshAccess()
    }

    private func refreshAccess() {
        switch manager.authorizationStatus {
        case .notDetermined:                      access = .notDetermined
        case .denied, .restricted:                access = .denied
        case .authorizedWhenInUse, .authorizedAlways: access = .granted
        @unknown default:                         access = .denied
        }
    }

    /// Pide permiso (si aun no se decidio) y devuelve si quedo concedido.
    func requestAccess() async -> Bool {
        if access == .notDetermined {
            manager.requestWhenInUseAuthorization()
            for _ in 0..<120 where access == .notDetermined {   // hasta ~30 s a que responda
                try? await Task.sleep(for: .milliseconds(250))
                refreshAccess()
            }
        }
        return access == .granted
    }

    /// Lee la posicion, resuelve la ciudad EN EL DISPOSITIVO y la manda al servidor.
    /// El servidor limita esto a una vez cada 15 minutos, asi que se puede llamar sin miedo.
    @discardableResult
    func syncToServer(api: any APIService = APIClient.shared) async -> Bool {
        guard access == .granted, !isUpdating else { return false }
        isUpdating = true
        defer { isUpdating = false }

        guard let location = await currentLocation() else { return false }
        let place = await Self.place(for: location)
        do {
            try await api.send(.location, body: LocationRequest(
                lat: location.coordinate.latitude, lng: location.coordinate.longitude,
                city: place.city, country: place.country
            ))
            return true
        } catch {
            return false
        }
    }

    private func currentLocation() async -> CLLocation? {
        if let last = manager.location, abs(last.timestamp.timeIntervalSinceNow) < 600 { return last }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    private static func place(for location: CLLocation) async -> (city: String?, country: String?) {
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return (nil, nil) }
        return (item.addressRepresentations?.cityName, item.addressRepresentations?.regionName)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refreshAccess() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.continuation?.resume(returning: locations.last)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            self.continuation?.resume(returning: nil)
            self.continuation = nil
        }
    }
}
