import Foundation

/// Lo que se recibe por el canal de una conversacion.
enum CableEvent: Sendable, Equatable {
    case message(ChatMessage)
    case read(messageIds: [String], readerId: String)
    case typing(userId: String)
}

/// Mensajes de bajo nivel del protocolo ActionCable (JSON). Separado del cliente
/// para poder probar el parseo sin red.
enum CableFrame: Equatable {
    case welcome
    case ping
    case confirmSubscription(identifier: String)
    case rejectSubscription(identifier: String)
    case disconnect(reason: String?, reconnect: Bool)
    case data(identifier: String, message: Data)
    case unknown

    static func parse(_ text: String) -> CableFrame {
        guard let data = text.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .unknown }

        let identifier = json["identifier"] as? String ?? ""
        switch json["type"] as? String {
        case "welcome":              return .welcome
        case "ping":                 return .ping
        case "confirm_subscription": return .confirmSubscription(identifier: identifier)
        case "reject_subscription":  return .rejectSubscription(identifier: identifier)
        case "disconnect":
            return .disconnect(reason: json["reason"] as? String, reconnect: json["reconnect"] as? Bool ?? true)
        default:
            guard !identifier.isEmpty, let message = json["message"],
                  let payload = try? JSONSerialization.data(withJSONObject: message) else { return .unknown }
            return .data(identifier: identifier, message: payload)
        }
    }

    /// El identificador de suscripcion es un JSON serializado dentro de un string.
    static func identifier(matchID: String) -> String {
        let object: [String: String] = ["channel": "ConversationChannel", "match_id": matchID]
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func subscribeCommand(identifier: String) -> String {
        command("subscribe", identifier: identifier)
    }

    static func performCommand(identifier: String, action: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [
            "command": "message", "identifier": identifier,
            "data": (String(data: (try? JSONSerialization.data(withJSONObject: ["action": action])) ?? Data(), encoding: .utf8)) ?? "{}"
        ] as [String: Any])
        return String(data: data ?? Data(), encoding: .utf8) ?? "{}"
    }

    private static func command(_ name: String, identifier: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: ["command": name, "identifier": identifier])
        return String(data: data ?? Data(), encoding: .utf8) ?? "{}"
    }
}

enum CableEventDecoder {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private struct MessageEnvelope: Decodable { let message: ChatMessage }
    private struct ReadEnvelope: Decodable { let readerId: String; let messageIds: [String] }
    private struct TypingEnvelope: Decodable { let userId: String }

    static func decode(_ payload: Data) -> CableEvent? {
        guard let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
              let type = object["type"] as? String else { return nil }
        switch type {
        case "message":
            return (try? decoder.decode(MessageEnvelope.self, from: payload)).map { .message($0.message) }
        case "read":
            return (try? decoder.decode(ReadEnvelope.self, from: payload)).map { .read(messageIds: $0.messageIds, readerId: $0.readerId) }
        case "typing":
            return (try? decoder.decode(TypingEnvelope.self, from: payload)).map { .typing(userId: $0.userId) }
        default:
            return nil
        }
    }
}
