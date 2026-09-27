import MapKit
import SwiftUI

/// Los grupos sobre un mapa. Las coordenadas llegan redondeadas a ~1 km desde
/// el servidor, asi que el pin marca el barrio, no la puerta de nadie.
struct GroupsMapView: View {
    let groups: [FriendGroup]
    let onOpen: (FriendGroup) -> Void

    @State private var selected: String?

    private var located: [FriendGroup] { groups.filter { $0.coordinate != nil } }

    var body: some View {
        Map(selection: $selected) {
            UserAnnotation()
            ForEach(located) { group in
                Marker(group.name,
                       systemImage: group.isPrivate ? "lock.fill" : "person.3.fill",
                       coordinate: group.coordinate!)
                    .tint(group.isMember ? Color.accentColor : .orange)
                    .tag(group.id)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay {
            if located.isEmpty {
                ContentUnavailableView("Ningún grupo con ubicación", systemImage: "map",
                                       description: Text("Los grupos creados con su ubicación aparecen aquí."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let group = located.first(where: { $0.id == selected }) { card(group) }
        }
    }

    private func card(_ group: FriendGroup) -> some View {
        Button { onOpen(group) } label: {
            HStack(spacing: 12) {
                Text(Labels.categories[group.category]?.emoji ?? "👥").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name).font(.headline).lineLimit(1)
                    Text([group.isPrivate ? "Privado" : "Público", "\(group.membersCount) miembros",
                          Labels.distance(group.distanceKm)].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
}
