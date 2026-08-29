import Foundation
import AppKit
import Observation
import CryptoKit
import Network

/// Spotify authorization via PKCE. No client secret is involved, so nothing sensitive ships
/// in the binary; the refresh token lives in the login keychain.
@Observable
final class SpotifyAuth {
    static let shared = SpotifyAuth()

    static let redirectURI = "http://127.0.0.1:8888/callback"
    private static let port: UInt16 = 8888
    private static let scope = "user-read-playback-state"

    enum Status: Equatable {
        case disconnected
        case waitingForBrowser
        case connected
        case failed(String)
    }

    private(set) var status: Status = .disconnected

    var clientID: String {
        didSet {
            let cleaned = Self.normalize(clientID)
            if cleaned != clientID {
                clientID = cleaned
                return
            }
            UserDefaults.standard.set(clientID, forKey: "spotifyClientID")
        }
    }

    /// Spotify client IDs are 32 lowercase hex characters. Catching a pasted secret or
    /// dashboard URL here is far clearer than a rejected authorize request.
    var isClientIDPlausible: Bool {
        clientID.count == 32 && clientID.allSatisfy(\.isHexDigit)
    }

    static let dashboardURL = URL(string: "https://developer.spotify.com/dashboard/create")!

    /// Accepts a bare ID, a dashboard URL, or either with stray whitespace around it.
    private static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("/") else { return trimmed }
        let candidates = trimmed.split(whereSeparator: { "/?#".contains($0) })
        return candidates.last(where: { $0.count == 32 && $0.allSatisfy(\.isHexDigit) })
            .map(String.init) ?? trimmed
    }

    @ObservationIgnored private var accessToken: String?
    @ObservationIgnored private var accessTokenExpiry = Date.distantPast
    @ObservationIgnored private var listener: CallbackListener?

    private init() {
        clientID = UserDefaults.standard.string(forKey: "spotifyClientID") ?? ""
        status = TokenStore.read() != nil ? .connected : .disconnected
    }

    var isConnected: Bool { status == .connected }

    // MARK: - Connect

    func connect() {
        guard !clientID.isEmpty else {
            status = .failed("Enter your Spotify app's Client ID first")
            return
        }
        guard isClientIDPlausible else {
            status = .failed("That does not look like a Client ID — it should be 32 letters and digits")
            return
        }

        let verifier = Self.randomVerifier()
        let challenge = Self.challenge(for: verifier)
        let state = Self.randomVerifier().prefix(16)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: String(state)),
            URLQueryItem(name: "scope", value: Self.scope),
        ]
        guard let url = components.url else { return }

        status = .waitingForBrowser
        let listener = CallbackListener(port: Self.port, expectedState: String(state))
        self.listener = listener
        listener.onCode = { [weak self] result in
            guard let self else { return }
            self.listener = nil
            switch result {
            case .success(let code):
                Task { await self.exchange(code: code, verifier: verifier) }
            case .failure(let message):
                self.status = .failed(message)
            }
        }
        guard listener.start() else {
            status = .failed("Port \(Self.port) is already in use")
            self.listener = nil
            return
        }
        Debug.log("authorize \(url.absoluteString)")
        NSWorkspace.shared.open(url)
    }

    /// Abandons a half-finished browser round trip without touching a stored token.
    func cancel() {
        listener?.stop()
        listener = nil
        status = TokenStore.read() != nil ? .connected : .disconnected
    }

    func disconnect() {
        TokenStore.delete()
        accessToken = nil
        accessTokenExpiry = .distantPast
        status = .disconnected
    }

    // MARK: - Tokens

    /// A valid bearer token, refreshing it when needed.
    func validAccessToken() async -> String? {
        if let accessToken, Date() < accessTokenExpiry { return accessToken }
        guard let refresh = TokenStore.read() else { return nil }
        return await requestToken(body: [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": clientID,
        ])
    }

    private func exchange(code: String, verifier: String) async {
        let token = await requestToken(body: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "client_id": clientID,
            "code_verifier": verifier,
        ])
        status = token == nil ? .failed(lastTokenError ?? "Token exchange failed") : .connected
    }

    @ObservationIgnored private var lastTokenError: String?

    private struct TokenResponse: Decodable {
        var access_token: String
        var expires_in: Double
        var refresh_token: String?
    }

    private func requestToken(body: [String: String]) async -> String? {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            lastTokenError = "Could not reach Spotify"
            return nil
        }
        guard http.statusCode == 200,
              let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            lastTokenError = Self.describe(errorBody: data) ?? "Spotify returned HTTP \(http.statusCode)"
            return nil
        }
        lastTokenError = nil

        accessToken = token.access_token
        accessTokenExpiry = Date().addingTimeInterval(token.expires_in - 30)
        if let refresh = token.refresh_token {
            TokenStore.write(refresh)
        }
        return token.access_token
    }

    private struct ErrorResponse: Decodable {
        var error: String?
        var error_description: String?
    }

    private static func describe(errorBody data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data) else { return nil }
        switch decoded.error {
        case "invalid_client":
            return "Spotify does not recognise that Client ID"
        case "invalid_grant":
            return "The redirect URI in your Spotify app does not match \(redirectURI)"
        default:
            return decoded.error_description ?? decoded.error
        }
    }

    // MARK: - PKCE helpers

    private static func randomVerifier() -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<64).map { _ in alphabet.randomElement()! })
    }

    private static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
