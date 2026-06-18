import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
final class YouTubeAuthService: NSObject, ObservableObject {
    @Published private(set) var accessToken: String?
    @Published private(set) var isSignedIn = false

    private var session: ASWebAuthenticationSession?
    private var codeVerifier = ""

    func signIn() async throws -> String {
        codeVerifier = Self.randomString(length: 64)
        let challenge = Self.codeChallenge(for: codeVerifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: YouTubeConfiguration.clientID),
            URLQueryItem(name: "redirect_uri", value: "\(YouTubeConfiguration.redirectScheme):/oauth2redirect"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: YouTubeConfiguration.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else { throw YouTubeAuthError.invalidURL }

        let callbackURL = try await authenticate(with: authURL)
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value else {
            throw YouTubeAuthError.missingCode
        }

        let token = try await exchangeCodeForToken(code)
        accessToken = token
        isSignedIn = true
        return token
    }

    func signOut() {
        accessToken = nil
        isSignedIn = false
    }

    private func authenticate(with authURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: YouTubeConfiguration.redirectScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: YouTubeAuthError.missingCallback)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session?.presentationContextProvider = self
            session?.prefersEphemeralWebBrowserSession = false
            session?.start()
        }
    }

    private func exchangeCodeForToken(_ code: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": YouTubeConfiguration.clientID,
            "redirect_uri": "\(YouTubeConfiguration.redirectScheme):/oauth2redirect",
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        request.httpBody = body
            .map { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw YouTubeAuthError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.accessToken
    }

    private static func randomString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

extension YouTubeAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        if let keyWindow = windowScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return keyWindow
        }

        if let windowScene = windowScenes.first {
            return ASPresentationAnchor(windowScene: windowScene)
        }

        return ASPresentationAnchor(frame: .zero)
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

enum YouTubeAuthError: LocalizedError {
    case invalidURL
    case missingCallback
    case missingCode
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Could not create the Google sign-in URL."
        case .missingCallback:
            "Google sign-in did not return to the app."
        case .missingCode:
            "Google sign-in completed without an authorization code."
        case .tokenExchangeFailed:
            "Could not exchange the Google authorization code for an access token."
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
