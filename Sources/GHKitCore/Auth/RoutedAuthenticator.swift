import Foundation

/// What a request is about, so an ``Authenticator`` can choose a credential for it.
public struct GitHubRequestContext: Sendable, Hashable {
    /// The part of the API the request belongs to, or `nil` for custom requests sent with `send(_:)`.
    public var domain: GitHubDomain?
    /// The user or organization login the request acts on, such as `"acme"` in `/repos/acme/app`.
    /// `nil` when the request isn't about one account, such as `GET /user`.
    public var owner: String?
    public var method: HTTPMethod

    public init(domain: GitHubDomain? = nil, owner: String? = nil, method: HTTPMethod = .get) {
        self.domain = domain
        self.owner = owner
        self.method = method
    }
}

/// Picks a different credential for some domains or accounts, and a default for everything else.
///
/// One classic or OAuth token can cover every domain, so most apps don't need this. Use it when:
/// - a fine-grained personal access token or GitHub App installation only reaches one account,
///   and you work with several
/// - you keep a more powerful token, such as an organization admin token, apart from the everyday one
///
/// ```swift
/// let github = GitHubClient(authenticator: .routed(
///     default: .token(personalToken),
///     domains: [.organizations: .token(orgAdminToken)],
///     owners: ["acme": InstallationAuthenticator(app: app, installationID: 42)]
/// ))
/// ```
///
/// For each request it uses the first match of: the domain and owner together, the owner, the domain,
/// then the default. The owner comes before the domain because an account-bound credential can't reach
/// other accounts at all. Logins match case-insensitively.
public struct RoutedAuthenticator: Authenticator {
    /// A domain and an account together, for ``use(_:for:owner:)``.
    struct Route: Hashable {
        var domain: GitHubDomain
        var owner: String
    }

    /// Used when no domain or owner matches.
    public var fallback: any Authenticator
    var domains: [GitHubDomain: any Authenticator]
    var owners: [String: any Authenticator]
    var routes: [Route: any Authenticator] = [:]

    /// - Parameters:
    ///   - fallback: The credential for requests nothing else matches.
    ///   - domains: Credentials for parts of the API, such as `.projects`.
    ///   - owners: Credentials for user or organization logins.
    public init(
        default fallback: some Authenticator,
        domains: [GitHubDomain: any Authenticator] = [:],
        owners: [String: any Authenticator] = [:]
    ) {
        self.fallback = fallback
        self.domains = domains
        self.owners = Dictionary(owners.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
    }

    /// Sends `authenticator`'s credentials for `domain`, or only for `domain` on `owner`'s resources.
    public mutating func use(_ authenticator: some Authenticator, for domain: GitHubDomain, owner: String? = nil) {
        if let owner {
            routes[Route(domain: domain, owner: owner.lowercased())] = authenticator
        } else {
            domains[domain] = authenticator
        }
    }

    /// Sends `authenticator`'s credentials for everything on `owner`'s resources.
    public mutating func use(_ authenticator: some Authenticator, forOwner owner: String) {
        owners[owner.lowercased()] = authenticator
    }

    public func authenticator(for context: GitHubRequestContext) -> any Authenticator {
        let owner = context.owner?.lowercased()
        let chosen: any Authenticator =
            if let domain = context.domain, let owner, let match = routes[Route(domain: domain, owner: owner)] {
                match
            } else if let owner, let match = owners[owner] {
                match
            } else if let domain = context.domain, let match = domains[domain] {
                match
            } else {
                fallback
            }
        // A routed authenticator can hold another one.
        return chosen.authenticator(for: context)
    }

    /// The default credential's header. ``GitHubClient`` asks ``authenticator(for:)`` first, so this
    /// only runs when something calls the authenticator without a request.
    public func authorization() async throws(GitHubError) -> String? {
        try await fallback.authorization()
    }

    public func refreshAfterUnauthorized() async throws(GitHubError) -> Bool {
        try await fallback.refreshAfterUnauthorized()
    }
}

extension Authenticator where Self == RoutedAuthenticator {
    /// Different credentials for some domains or accounts. See ``RoutedAuthenticator``.
    public static func routed(
        default fallback: some Authenticator,
        domains: [GitHubDomain: any Authenticator] = [:],
        owners: [String: any Authenticator] = [:]
    ) -> RoutedAuthenticator {
        RoutedAuthenticator(default: fallback, domains: domains, owners: owners)
    }
}
