import Foundation
import Network
import SummonCore

/// Lightweight HTTP server on port 14732 for the companion Cowork plugin.
///
/// Routes:
///   GET  /health      — liveness check
///   GET  /snippets    — all snippets as JSON
///   POST /snippets    — create a snippet {trigger, expansion, label?}
///   DELETE /snippets/:id — delete a snippet by UUID
final class CompanionServer: @unchecked Sendable {
    static let shared = CompanionServer()
    static let port: UInt16 = 14732

    private var listener: NWListener?
    private var store: SnippetStore?

    func start(store: SnippetStore) {
        self.store = store
        guard listener == nil else { return }
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: Self.port)!)
            listener?.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
            listener?.start(queue: .global(qos: .utility))
        } catch {
            print("[CompanionServer] failed: \(error)")
        }
    }

    // MARK: - Connection

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .utility))
        readRequest(conn)
    }

    private func readRequest(_ conn: NWConnection, accumulated: Data = Data()) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, _ in
            guard let self else { return }
            var buf = accumulated
            if let data { buf.append(data) }

            if let raw = String(data: buf, encoding: .utf8), raw.contains("\r\n\r\n") {
                Task { await self.route(raw: raw, conn: conn) }
            } else if !isComplete {
                self.readRequest(conn, accumulated: buf)
            } else {
                conn.cancel()
            }
        }
    }

    // MARK: - Routing

    private func route(raw: String, conn: NWConnection) async {
        let parts = raw.components(separatedBy: "\r\n\r\n")
        let headers = parts[0]
        let body    = parts.count > 1 ? parts[1] : ""
        let firstLine = headers.components(separatedBy: "\r\n").first ?? ""
        let tokens    = firstLine.components(separatedBy: " ")
        guard tokens.count >= 2 else { respond(conn, 400, "{\"error\":\"bad request\"}"); return }

        let method = tokens[0]
        let path   = tokens[1].components(separatedBy: "?")[0]

        switch (method, path) {
        case ("GET", "/health"):
            respond(conn, 200, "{\"status\":\"ok\",\"app\":\"Summon\",\"version\":\"\(AppVersion.current)\",\"port\":\(Self.port)}")

        case ("GET", "/snippets"):
            guard let store else { respond(conn, 503, "{\"error\":\"store unavailable\"}"); return }
            let all = await store.snippets
            let dtos = all.map { SnippetDTO($0) }
            respond(conn, 200, encode(dtos))

        case ("POST", "/snippets"):
            guard
                let store,
                let data = body.data(using: .utf8),
                let dto  = try? JSONDecoder().decode(NewSnippetDTO.self, from: data),
                !dto.trigger.isEmpty, !dto.expansion.isEmpty
            else { respond(conn, 400, "{\"error\":\"invalid body\"}"); return }
            let s = Snippet(trigger: dto.trigger, expansion: dto.expansion, label: dto.label ?? "")
            do {
                try await store.add(s)
                respond(conn, 201, "{\"ok\":true,\"id\":\"\(s.id.uuidString)\"}")
            } catch {
                respond(conn, 409, "{\"error\":\"\(error.localizedDescription)\"}")
            }

        case let (m, p) where m == "DELETE" && p.hasPrefix("/snippets/"):
            let idStr = String(p.dropFirst("/snippets/".count))
            guard let id = UUID(uuidString: idStr), let store else {
                respond(conn, 400, "{\"error\":\"invalid id\"}"); return
            }
            try? await store.delete(id: id)
            respond(conn, 200, "{\"ok\":true}")

        default:
            respond(conn, 404, "{\"error\":\"not found\"}")
        }
    }

    // MARK: - Response

    private func respond(_ conn: NWConnection, _ status: Int, _ body: String) {
        let statusText = status == 200 ? "OK" : status == 201 ? "Created" : "Error"
        let http = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        conn.send(content: http.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })
    }

    private func encode<T: Encodable>(_ v: T) -> String {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return (try? enc.encode(v)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}

// MARK: - DTOs

private struct SnippetDTO: Encodable {
    let id: String; let trigger: String; let expansion: String
    let label: String; let enabled: Bool; let createdAt: String
    init(_ s: Snippet) {
        id = s.id.uuidString; trigger = s.trigger; expansion = s.expansion
        label = s.label; enabled = s.enabled
        createdAt = ISO8601DateFormatter().string(from: s.createdAt)
    }
}

private struct NewSnippetDTO: Decodable {
    let trigger: String; let expansion: String; let label: String?
}
