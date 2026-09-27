import Foundation
import Observation

/// Grupos: los mios y el descubrimiento por categoria o busqueda.
@MainActor
@Observable
final class GroupsViewModel {
    enum Phase { case loading, ready, failed }

    private(set) var mine: [FriendGroup] = []
    private(set) var discover: [FriendGroup] = []
    private(set) var phase: Phase = .loading
    var category: String? { didSet { if category != oldValue { reloadDiscover() } } }
    var query = "" { didSet { if query != oldValue { reloadDiscover(debounced: true) } } }
    var error: AlertMessage?

    private let api: any APIService
    private var searchTask: Task<Void, Never>?

    init(api: any APIService = APIClient.shared) { self.api = api }

    /// Tus grupos, filtrados por lo que estes buscando.
    ///
    /// Buscar tiene que encontrar TAMBIEN los tuyos. El servidor los excluye
    /// del descubrimiento a proposito —ya estas dentro, no hay nada que
    /// descubrir—, asi que si el filtro no se aplicara aqui, buscar un grupo
    /// tuyo por su nombre no daria ningun resultado.
    var visibleMine: [FriendGroup] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return mine }
        return mine.filter {
            $0.name.localizedCaseInsensitiveContains(needle)
                || ($0.description ?? "").localizedCaseInsensitiveContains(needle)
        }
    }

    /// Ni uno ni otro: hace falta para distinguir "no hay nada" de "no hay
    /// nada NUEVO", que no es lo mismo cuando el tuyo si aparece arriba.
    var hasNoResults: Bool { visibleMine.isEmpty && discover.isEmpty }

    func load() async {
        async let mineResponse: GroupsResponse? = try? api.send(.groups(scope: .mine, category: nil, query: nil))
        async let discoverResponse: GroupsResponse? = try? api.send(.groups(scope: .discover, category: category, query: query))
        let (mineResult, discoverResult) = await (mineResponse, discoverResponse)

        guard mineResult != nil || discoverResult != nil else {
            if mine.isEmpty && discover.isEmpty { phase = .failed }
            return
        }
        mine = mineResult?.groups ?? mine
        discover = discoverResult?.groups ?? []
        phase = .ready
    }

    /// El buscador escribe letra a letra: se espera un poco antes de pedir.
    private func reloadDiscover(debounced: Bool = false) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            if debounced { try? await Task.sleep(for: .milliseconds(350)) }
            guard !Task.isCancelled else { return }
            let response: GroupsResponse? = try? await api.send(.groups(scope: .discover, category: category, query: query))
            guard !Task.isCancelled, let response else { return }
            discover = response.groups
        }
    }

    /// Mueve el grupo entre las dos listas sin esperar a recargar.
    func didJoin(_ group: FriendGroup) {
        discover.removeAll { $0.id == group.id }
        if !mine.contains(where: { $0.id == group.id }) { mine.insert(group, at: 0) }
    }

    func didLeave(_ group: FriendGroup) {
        mine.removeAll { $0.id == group.id }
        Task { await load() }
    }
}

/// Estado de un grupo abierto: su ficha, sus miembros y la pertenencia.
@MainActor
@Observable
final class GroupDetailViewModel {
    private(set) var group: FriendGroup
    private(set) var members: [Person] = []
    private(set) var requests: [JoinRequestItem] = []
    private(set) var isWorking = false
    var error: AlertMessage?

    private let api: any APIService

    init(group: FriendGroup, api: any APIService = APIClient.shared) {
        self.group = group
        self.api = api
    }

    func load() async {
        if let response: GroupResponse = try? await api.send(.group(slug: group.slug)) { group = response.group }
        if group.isMember, let response: MembersResponse = try? await api.send(.members(slug: group.slug)) {
            members = response.members
        }
        if group.canModerate, group.isPrivate,
           let response: JoinRequestsResponse = try? await api.send(.groupRequests(slug: group.slug)) {
            requests = response.requests
        }
    }

    /// Devuelve el grupo ya actualizado si la pertenencia cambio. En un grupo
    /// privado no cambia: queda una peticion pendiente y `group.hasRequested`.
    func join() async -> FriendGroup? {
        isWorking = true
        defer { isWorking = false }
        do {
            let response: JoinResponse = try await api.send(.join(slug: group.slug))
            await load()
            if response.joined { return group }
            if response.requested != true { self.error = AlertMessage("No se pudo unir al grupo") }
            return nil
        } catch APIError.server(_, let message) {
            self.error = AlertMessage("No se pudo unir al grupo", message: message)
            return nil
        } catch {
            self.error = AlertMessage("No se pudo unir al grupo")
            return nil
        }
    }

    func cancelRequest() async {
        do {
            try await api.send(.cancelRequest(slug: group.slug))
            await load()
        } catch {
            self.error = AlertMessage("No se pudo retirar la solicitud")
        }
    }

    func decide(_ request: JoinRequestItem, approve: Bool) async {
        do {
            try await api.send(approve ? .approveRequest(slug: group.slug, id: request.id)
                                       : .rejectRequest(slug: group.slug, id: request.id))
            requests.removeAll { $0.id == request.id }
            await load()
        } catch {
            self.error = AlertMessage(approve ? "No se pudo aceptar" : "No se pudo rechazar",
                                      message: "Inténtalo de nuevo.")
        }
    }

    func leave() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await api.send(.leave(slug: group.slug))
            return true
        } catch {
            self.error = AlertMessage("No se pudo salir del grupo")
            return false
        }
    }

    func kick(_ person: Person) async {
        do {
            try await api.send(.kick(slug: group.slug, userID: person.userId))
            members.removeAll { $0.id == person.id }
        } catch {
            self.error = AlertMessage("No se pudo expulsar a esta persona")
        }
    }
}
