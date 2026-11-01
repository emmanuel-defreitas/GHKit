import Foundation
import Security
import Testing

@testable import GHKit

@Suite("Authentication")
struct AuthTests {
    // MARK: Device flow

    @Test func deviceFlowStartsAndPolls() async throws {
        let transport = MockTransport { request, index in
            switch (request.path, index) {
            case ("/login/device/code", _):
                return .json(
                    #"{"device_code":"dev123","user_code":"WDJB-MJHT","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}"#)
            case (_, 1):
                return .json(#"{"error":"authorization_pending"}"#)
            case (_, 2):
                return .json(#"{"error":"slow_down","interval":10}"#)
            default:
                return .json(#"{"access_token":"gho_abc","token_type":"bearer","scope":"repo,read:org"}"#)
            }
        }
        let sleeps = SleepRecorder()
        var flow = DeviceFlow(clientID: "Iv1.test", scopes: [.repo, .readOrg], transport: transport)
        flow.sleep = sleeps.sleep

        let authorization = try await flow.start()
        #expect(authorization.userCode == "WDJB-MJHT")
        #expect(authorization.interval == .seconds(5))

        let credential = try await flow.waitForAuthorization(authorization)
        #expect(credential.accessToken == "gho_abc")
        #expect(credential.scopes == [.repo, .readOrg])
        #expect(sleeps.durations == [.seconds(5), .seconds(5), .seconds(10)])

        let start = transport.requests[0]
        #expect(start.url?.absoluteString == "https://github.com/login/device/code")
        #expect(start.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(start.formBody == ["client_id": "Iv1.test", "scope": "repo read:org"])
        #expect(transport.requests[1].formBody["grant_type"] == "urn:ietf:params:oauth:grant-type:device_code")
        #expect(transport.requests[1].formBody["device_code"] == "dev123")
    }

    @Test func deviceFlowReportsDenial() async {
        let transport = MockTransport(.json(#"{"error":"access_denied","error_description":"The user cancelled."}"#))
        var flow = DeviceFlow(clientID: "Iv1.test", transport: transport)
        flow.sleep = { _ in }
        let authorization = DeviceAuthorization(
            deviceCode: "d", userCode: "u", verificationURL: URL(string: "https://github.com/login/device")!,
            expiresAt: .now.addingTimeInterval(900), interval: .seconds(5))
        do {
            _ = try await flow.waitForAuthorization(authorization)
            Issue.record("Expected an error")
        } catch {
            guard case .oauth(let oauth) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(oauth.code == .accessDenied)
            #expect(oauth.errorDescription == "The user cancelled.")
        }
    }

    @Test func deviceFlowStopsWhenCodeExpires() async {
        let transport = MockTransport(.json(#"{"error":"authorization_pending"}"#))
        var flow = DeviceFlow(clientID: "Iv1.test", transport: transport)
        flow.sleep = { _ in }
        let authorization = DeviceAuthorization(
            deviceCode: "d", userCode: "u", verificationURL: URL(string: "https://github.com/login/device")!,
            expiresAt: .now.addingTimeInterval(-1), interval: .seconds(5))
        do {
            _ = try await flow.waitForAuthorization(authorization)
            Issue.record("Expected an error")
        } catch {
            guard case .oauth(let oauth) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(oauth.code == .expiredToken)
        }
        #expect(transport.requests.isEmpty)
    }

    // MARK: Web flow

    @Test func pkceMatchesRFC7636Example() {
        #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(PKCE.makeVerifier().count == 43)
    }

    @Test func authorizeURLHasEveryParameter() throws {
        let flow = OAuthWebFlow(clientID: "abc", clientSecret: nil, redirectURI: URL(string: "myapp://oauth")!, scopes: [.repo, .project])
        let request = flow.makeAuthorizationRequest(login: "octocat")
        let items = URLRequest(url: request.url).queryItems
        #expect(request.url.absoluteString.hasPrefix("https://github.com/login/oauth/authorize?"))
        #expect(items["client_id"] == "abc")
        #expect(items["redirect_uri"] == "myapp://oauth")
        #expect(items["scope"] == "repo project")
        #expect(items["state"] == request.state)
        #expect(items["code_challenge"] == PKCE.challenge(for: request.codeVerifier))
        #expect(items["code_challenge_method"] == "S256")
        #expect(items["login"] == "octocat")
    }

    @Test func callbackExchangeChecksState() async throws {
        let transport = MockTransport(
            .json(#"{"access_token":"ghu_x","token_type":"bearer","scope":"","expires_in":28800,"refresh_token":"ghr_y","refresh_token_expires_in":15897600}"#))
        let flow = OAuthWebFlow(clientID: "abc", clientSecret: "shh", redirectURI: URL(string: "myapp://oauth")!, transport: transport)
        let request = flow.makeAuthorizationRequest()

        await #expect(throws: GitHubError.self) {
            _ = try await flow.exchange(callbackURL: URL(string: "myapp://oauth?code=c&state=wrong")!, for: request)
        }
        #expect(transport.requests.isEmpty)

        let credential = try await flow.exchange(callbackURL: URL(string: "myapp://oauth?code=c&state=\(request.state)")!, for: request)
        #expect(credential.accessToken == "ghu_x")
        #expect(credential.refreshToken == "ghr_y")
        #expect(credential.expiresAt != nil)
        let form = transport.requests[0].formBody
        #expect(form["code"] == "c")
        #expect(form["client_secret"] == "shh")
        #expect(form["code_verifier"] == request.codeVerifier)
    }

    @Test func callbackErrorBecomesOAuthError() async {
        let flow = OAuthWebFlow(clientID: "abc", clientSecret: nil, redirectURI: URL(string: "myapp://oauth")!, transport: MockTransport(.json("{}")))
        let request = flow.makeAuthorizationRequest()
        do {
            _ = try await flow.exchange(callbackURL: URL(string: "myapp://oauth?error=access_denied&state=\(request.state)")!, for: request)
            Issue.record("Expected an error")
        } catch {
            guard case .oauth(let oauth) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(oauth.code == .accessDenied)
        }
    }

    // MARK: Refreshing tokens

    @Test func oauthAuthenticatorRefreshesExpiredTokensOnce() async throws {
        let transport = MockTransport { _, _ in
            .json(#"{"access_token":"ghu_new","token_type":"bearer","expires_in":28800,"refresh_token":"ghr_new","refresh_token_expires_in":15897600}"#)
        }
        let store = InMemoryCredentialStore()
        let expired = OAuthCredential(accessToken: "ghu_old", expiresAt: .now.addingTimeInterval(-10), refreshToken: "ghr_old")
        let auth = OAuthAuthenticator(credential: expired, refresh: .init(clientID: "Iv1.test"), store: store, transport: transport)

        let headers = try await withThrowingTaskGroup(of: String?.self) { group in
            for _ in 0..<5 { group.addTask { try await auth.authorization() } }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(headers.allSatisfy { $0 == "Bearer ghu_new" })
        #expect(transport.requests.count == 1)
        #expect(transport.requests[0].formBody["grant_type"] == "refresh_token")
        #expect(transport.requests[0].formBody["refresh_token"] == "ghr_old")
        #expect(await store.load()?.accessToken == "ghu_new")
    }

    @Test func validTokensAreNotRefreshed() async throws {
        let transport = MockTransport(.json("{}"))
        let fresh = OAuthCredential(accessToken: "ghu_ok", expiresAt: .now.addingTimeInterval(3600), refreshToken: "ghr")
        let auth = OAuthAuthenticator(credential: fresh, refresh: .init(clientID: "Iv1.test"), transport: transport)
        #expect(try await auth.authorization() == "Bearer ghu_ok")
        #expect(transport.requests.isEmpty)
    }

    // MARK: GitHub Apps

    @Test func appJWTIsSignedAndVerifiable() throws {
        let (privateKey, publicKey) = try makeRSAKeyPair()
        let pem = pemEncode(privateKey, label: "RSA PRIVATE KEY")
        let credentials = try GitHubAppCredentials(issuer: "Iv23liTest", privateKeyPEM: pem)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let jwt = try credentials.makeJWT(now: now)
        let parts = jwt.split(separator: ".").map(String.init)
        #expect(parts.count == 3)

        let payload = try JSONDecoder().decode(JSONValue.self, from: base64URLDecode(parts[1]))
        #expect(payload["iss"]?.stringValue == "Iv23liTest")
        #expect(payload["iat"]?.intValue == 1_699_999_940)
        #expect(payload["exp"]?.intValue == 1_700_000_540)

        var error: Unmanaged<CFError>?
        let signingInput = Data("\(parts[0]).\(parts[1])".utf8)
        let valid = SecKeyVerifySignature(publicKey, .rsaSignatureMessagePKCS1v15SHA256, signingInput as CFData, base64URLDecode(parts[2]) as CFData, &error)
        #expect(valid)
    }

    @Test func pkcs8KeysAreUnwrapped() throws {
        let (privateKey, _) = try makeRSAKeyPair()
        let pkcs8 = wrapPKCS8(privateKey)
        let key = try RSAPrivateKey(pem: pemEncode(pkcs8, label: "PRIVATE KEY"))
        #expect(key.der == privateKey)
    }

    @Test func installationTokensAreCachedAndShared() async throws {
        let (privateKey, _) = try makeRSAKeyPair()
        let app = try GitHubAppCredentials(issuer: "Iv23liTest", privateKeyPEM: pemEncode(privateKey, label: "RSA PRIVATE KEY"))
        let expires = ISO8601DateFormatter().string(from: .now.addingTimeInterval(3600))
        let transport = MockTransport(.json(#"{"token":"ghs_install","expires_at":"\#(expires)","permissions":{"issues":"write"}}"#, status: 201))
        let auth = InstallationAuthenticator(app: app, installationID: 42, transport: transport)

        let headers = try await withThrowingTaskGroup(of: String?.self) { group in
            for _ in 0..<4 { group.addTask { try await auth.authorization() } }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(headers.allSatisfy { $0 == "Bearer ghs_install" })
        #expect(transport.requests.count == 1)
        let request = transport.requests[0]
        #expect(request.path == "/app/installations/42/access_tokens")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ey") == true)
    }

    @Test func installationFixtureDecodes() throws {
        let installation = try GitHubJSON.decoder().decode(Installation.self, from: loadFixture("installation"))
        #expect(installation.account?.displayName == "github")
        let app = try GitHubJSON.decoder().decode(GitHubApp.self, from: loadFixture("integration"))
        #expect(app.owner?.login == "octocat")
        let token = try GitHubJSON.decoder().decode(InstallationToken.self, from: loadFixture("installation-token"))
        #expect(token.token.hasPrefix("ghs_"))
    }

    @Test func oauthApplicationUsesBasicAuth() async throws {
        let transport = MockTransport(.noContent())
        try await makeClient(transport).oauthApplication(clientID: "Iv1.app", clientSecret: "secret").deleteToken("gho_x")
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "DELETE")
        #expect(request.path == "/applications/Iv1.app/token")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic " + Data("Iv1.app:secret".utf8).base64EncodedString())
        #expect(request.jsonBody?["access_token"]?.stringValue == "gho_x")
    }
}

// MARK: - Key helpers

private func makeRSAKeyPair() throws -> (privateKey: Data, publicKey: SecKey) {
    let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: 2048]
    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
        let data = SecKeyCopyExternalRepresentation(key, &error) as Data?,
        let publicKey = SecKeyCopyPublicKey(key)
    else { throw error!.takeRetainedValue() }
    return (data, publicKey)
}

private func pemEncode(_ der: Data, label: String) -> String {
    let base64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
    return "-----BEGIN \(label)-----\n\(base64)\n-----END \(label)-----\n"
}

private func base64URLDecode(_ string: String) -> Data {
    var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while base64.count % 4 != 0 { base64 += "=" }
    return Data(base64Encoded: base64)!
}

/// Wraps a PKCS#1 RSA key in a PKCS#8 PrivateKeyInfo.
private func wrapPKCS8(_ pkcs1: Data) -> Data {
    func element(_ tag: UInt8, _ contents: [UInt8]) -> [UInt8] {
        var length: [UInt8]
        if contents.count < 0x80 {
            length = [UInt8(contents.count)]
        } else {
            var n = contents.count
            var bytes: [UInt8] = []
            while n > 0 { bytes.insert(UInt8(n & 0xFF), at: 0); n >>= 8 }
            length = [0x80 | UInt8(bytes.count)] + bytes
        }
        return [tag] + length + contents
    }
    let rsaOID: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
    let algorithm = element(0x30, rsaOID + [0x05, 0x00])
    let version = element(0x02, [0x00])
    return Data(element(0x30, version + algorithm + element(0x04, [UInt8](pkcs1))))
}
