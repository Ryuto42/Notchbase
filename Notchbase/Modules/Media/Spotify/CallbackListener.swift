import Foundation
import Network

final class CallbackListener {
    enum Result {
        case success(String)
        case failure(String)
    }

    var onCode: ((Result) -> Void)?

    private let port: UInt16
    private let expectedState: String
    private var listener: NWListener?
    private var finished = false

    init(port: UInt16, expectedState: String) {
        self.port = port
        self.expectedState = expectedState
    }

    func start() -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: nwPort)
        guard let listener = try? NWListener(using: parameters) else { return false }
        self.listener = listener

        listener.newConnectionHandler = { connection in
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                Task { @MainActor in
                    let accepted = self.handle(request)
                    let status = accepted ? "200 OK" : "400 Bad Request"
                    let body = accepted ? "You can close this tab and return to Notchbase." : "Invalid request."
                    let response = """
                    HTTP/1.1 \(status)\r
                    Content-Type: text/plain; charset=utf-8\r
                    Content-Length: \(body.utf8.count)\r
                    Connection: close\r
                    \r
                    \(body)
                    """
                    connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            }
        }
        listener.start(queue: .main)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(180))
            self?.finish(.failure("Authorization timed out"))
        }
        return true
    }

    func stop() {
        finished = true
        listener?.cancel()
        listener = nil
    }

    /// Requests that are malformed or carry the wrong state are ignored, and the listener keeps waiting.
    private func handle(_ request: String) -> Bool {
        guard !finished,
              let line = request.split(separator: "\r\n").first,
              line.hasPrefix("GET "),
              let path = line.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: "http://127.0.0.1\(path)"),
              components.path == "/callback" else { return false }
        let items = components.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == expectedState else { return false }
        if let error = items.first(where: { $0.name == "error" })?.value {
            finish(.failure(error))
        } else if let code = items.first(where: { $0.name == "code" })?.value {
            finish(.success(code))
        } else {
            finish(.failure("No authorization code in callback"))
        }
        return true
    }

    private func finish(_ result: Result) {
        guard !finished else { return }
        finished = true
        listener?.cancel()
        listener = nil
        onCode?(result)
    }
}
