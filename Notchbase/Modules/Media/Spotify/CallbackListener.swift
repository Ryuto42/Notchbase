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
        guard let nwPort = NWEndpoint.Port(rawValue: port),
              let listener = try? NWListener(using: .tcp, on: nwPort) else { return false }
        self.listener = listener

        listener.newConnectionHandler = { connection in
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let body = "You can close this tab and return to Notchbase."
                let response = """
                HTTP/1.1 200 OK\r
                Content-Type: text/plain; charset=utf-8\r
                Content-Length: \(body.utf8.count)\r
                Connection: close\r
                \r
                \(body)
                """
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                Task { @MainActor in self.handle(request) }
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

    private func handle(_ request: String) {
        guard let line = request.split(separator: "\r\n").first,
              let path = line.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: "http://127.0.0.1\(path)") else {
            finish(.failure("Malformed callback"))
            return
        }
        let items = components.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == expectedState else {
            finish(.failure("State mismatch"))
            return
        }
        if let error = items.first(where: { $0.name == "error" })?.value {
            finish(.failure(error))
        } else if let code = items.first(where: { $0.name == "code" })?.value {
            finish(.success(code))
        } else {
            finish(.failure("No authorization code in callback"))
        }
    }

    private func finish(_ result: Result) {
        guard !finished else { return }
        finished = true
        listener?.cancel()
        listener = nil
        onCode?(result)
    }
}
