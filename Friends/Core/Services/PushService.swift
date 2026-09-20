import Foundation
import UIKit
import UserNotifications

/// Notificaciones push.
///
/// El servidor ya las manda desde hace tiempo (`NotifyMatchJob`,
/// `NotifyMessageJob`): lo que faltaba era que la app pidiera permiso, diera de
/// alta su token y supiera abrir la conversacion al tocar el aviso. Sin esto,
/// un match o un mensaje solo se descubren abriendo la app a ver.
///
/// El permiso NO se pide al arrancar. Se pide cuando ya se entiende para que
/// sirve: en el primer match.
@MainActor
@Observable
final class PushService: NSObject {
    static let shared = PushService()

    enum Access { case notDetermined, denied, granted }

    private(set) var access: Access = .notDetermined
    /// Token APNs en hexadecimal, tal y como lo espera el servidor.
    private(set) var deviceToken: String?

    /// El aviso de APNs trae `{"type": "match"|"message", "match_id": "..."}`.
    /// Al tocarlo se apunta aqui y `RootView` lleva a esa conversacion.
    var pendingMatchID: String?
    /// Mientras estas DENTRO de una conversacion no tiene sentido enseñar un
    /// banner de esa misma conversacion.
    var visibleMatchID: String?

    private let api: any APIService
    private var registeredToken: String?

    /// APNs tiene dos entornos y un token de uno no vale en el otro. La build
    /// de desarrollo habla con el sandbox; la que se sube, con el de verdad.
    static var environment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    init(api: any APIService = APIClient.shared) {
        self.api = api
        super.init()
    }

    // MARK: - Permiso

    func refreshAccess() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        access = switch settings.authorizationStatus {
        case .notDetermined:                       .notDetermined
        case .denied:                              .denied
        case .authorized, .provisional, .ephemeral: .granted
        @unknown default:                          .denied
        }
    }

    /// Pide el permiso si aun no se decidio y, si hay luz verde, se registra.
    @discardableResult
    func requestAccess() async -> Bool {
        await refreshAccess()
        if access == .notDetermined {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            access = granted ? .granted : .denied
        }
        guard access == .granted else { return false }
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    /// Al volver a la app: si el permiso ya estaba dado, se renueva el token
    /// sin molestar con ninguna pregunta.
    func registerIfAlreadyAllowed() async {
        await refreshAccess()
        guard access == .granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Token

    /// APNs entrega el token en binario; el servidor lo quiere en hexadecimal.
    /// `%02x` y no `%x`: sin el relleno, un byte como 0x0a se escribiria "a" y
    /// el token quedaria corrido y no valdria para nada.
    nonisolated static func hexToken(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    func didRegister(deviceToken data: Data) {
        let token = Self.hexToken(from: data)
        deviceToken = token
        guard token != registeredToken else { return }
        Task { await send(token: token) }
    }

    private func send(token: String) async {
        do {
            try await api.send(.registerDevice,
                               body: DeviceRequest(token: token, environment: Self.environment))
            registeredToken = token
        } catch {
            // Que no se registre no puede romper nada: se reintenta al volver
            // a primer plano.
            registeredToken = nil
        }
    }

    /// Al cerrar sesion: el aviso de un match ajeno no puede seguir llegando a
    /// este telefono.
    func unregister() async {
        guard let token = deviceToken ?? registeredToken else { return }
        setBadge(0)
        try? await api.send(.unregisterDevice(token: token))
        registeredToken = nil
        deviceToken = nil
    }

    // MARK: - Globo del icono

    /// No se espera a que termine: `setBadgeCount` tarda lo que quiera —en el
    /// banco de pruebas, mas de un minuto— y ni cerrar sesion ni pintar la
    /// lista de chats tienen por que quedarse parados detras del globo.
    nonisolated func setBadge(_ count: Int) {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(max(0, count)) }
    }

    // MARK: - Avisos recibidos

    /// El `match_id` que viaja en el aviso, si lo hay. `nonisolated`: se lee
    /// en el delegado de notificaciones, que no corre en el main actor.
    nonisolated static func matchID(in userInfo: [AnyHashable: Any]) -> String? {
        (userInfo["match_id"] as? String) ?? (userInfo["data"] as? [String: Any])?["match_id"] as? String
    }
}

/// Lo minimo que hay que tener en UIKit: APNs entrega el token y los toques de
/// los avisos por el delegado de la app, no por SwiftUI.
final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushService.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        // En el simulador y en builds sin firmar esto falla siempre. No es algo
        // que contarle a nadie.
    }
}

extension PushAppDelegate: UNUserNotificationCenterDelegate {
    /// Con la app abierta: banner si no estas ya en esa conversacion.
    ///
    /// `nonisolated` porque `UNNotification` no es Sendable y no puede cruzar
    /// al main actor: de aqui solo sale el id, que es un String.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let matchID = PushService.matchID(in: notification.request.content.userInfo)
        let isOpen = await MainActor.run { matchID != nil && PushService.shared.visibleMatchID == matchID }
        return isOpen ? [] : [.banner, .sound, .badge]
    }

    /// Al tocar el aviso: se apunta a donde hay que ir.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let matchID = PushService.matchID(in: response.notification.request.content.userInfo) else { return }
        await MainActor.run { PushService.shared.pendingMatchID = matchID }
    }
}
