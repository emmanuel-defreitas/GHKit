import GHKit
import SwiftUI

#if os(iOS) || os(macOS) || os(visionOS)
    import AuthenticationServices
#endif

extension EnvironmentValues {
    /// The client views should use, or `nil` when signed out.
    @Entry public var gitHubClient: GitHubClient? = nil
}

extension View {
    /// Puts a client in the environment for `@Environment(\.gitHubClient)`.
    public func gitHubClient(_ client: GitHubClient?) -> some View {
        environment(\.gitHubClient, client)
    }
}

#if os(iOS) || os(macOS) || os(visionOS)
    extension OAuthWebFlow {
        /// Runs the web flow in a system browser sheet and exchanges the code.
        ///
        ///     @Environment(\.webAuthenticationSession) private var webAuth
        ///     let credential = try await flow.authenticate(using: webAuth, callbackURLScheme: "myapp")
        ///     try await session.signIn(credential: credential)
        ///
        /// The exchange needs the client secret. Prefer device flow in shipping apps,
        /// or exchange the code on your server with ``OAuthWebFlow/exchange(code:codeVerifier:)``.
        public func authenticate(
            using webAuthenticationSession: WebAuthenticationSession,
            callbackURLScheme: String,
            ephemeral: Bool = false
        ) async throws(GitHubError) -> OAuthCredential {
            let request = makeAuthorizationRequest()
            let callbackURL: URL
            do {
                callbackURL = try await webAuthenticationSession.authenticate(
                    using: request.url,
                    callbackURLScheme: callbackURLScheme,
                    preferredBrowserSession: ephemeral ? .ephemeral : .shared
                )
            } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                throw .cancelled
            } catch {
                throw .authentication(error.localizedDescription)
            }
            return try await exchange(callbackURL: callbackURL, for: request)
        }
    }
#endif
