import Foundation
import GHKitCore

/// URL templates for the API's main resources (`root`).
public struct APIRoot: Sendable, Hashable, Codable {
    /// Templates by name, such as `user_url` for `https://api.github.com/users/{user}`.
    public var links: [String: String]

    public subscript(name: String) -> String? { links[name] }

    public init(from decoder: any Decoder) throws {
        links = try decoder.singleValueContainer().decode([String: String].self)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(links)
    }
}

/// GitHub's IP ranges, SSH host keys, and domains (`api-overview`).
///
/// IP ranges are in CIDR notation, such as `192.30.252.0/22`.
public struct GitHubMeta: Sendable, Hashable, Codable {
    public var verifiablePasswordAuthentication: Bool
    /// Host key fingerprints by algorithm, such as `SHA256_ED25519`.
    public var sshKeyFingerprints: [String: String]?
    /// Host public keys, for `known_hosts`.
    public var sshKeys: [String]?
    /// Where webhooks come from.
    public var hooks: [String]?
    public var web: [String]?
    public var api: [String]?
    public var git: [String]?
    public var githubEnterpriseImporter: [String]?
    public var sharedIngress: [String]?
    public var packages: [String]?
    public var pages: [String]?
    public var importer: [String]?
    /// Where GitHub-hosted Actions runners connect from.
    public var actions: [String]?
    public var actionsMacOS: [String]?
    public var codespaces: [String]?
    public var dependabot: [String]?
    public var copilot: [String]?
    /// Public keys GitHub signs web commits with.
    public var commitSigningKeys: [String]?
    public var domains: Domains?

    /// Domains by service, with `*` wildcards.
    public struct Domains: Sendable, Hashable, Codable {
        public var website: [String]?
        public var codespaces: [String]?
        public var copilot: [String]?
        public var packages: [String]?
        public var storage: [String]?
        public var actions: [String]?
        public var actionsInbound: Inbound?
        public var artifactAttestations: ArtifactAttestations?

        /// Domains Actions runners must reach.
        public struct Inbound: Sendable, Hashable, Codable {
            public var fullDomains: [String]?
            public var wildcardDomains: [String]?

            enum CodingKeys: String, CodingKey {
                case fullDomains = "full_domains"
                case wildcardDomains = "wildcard_domains"
            }
        }

        /// Where artifact attestations are signed and stored.
        public struct ArtifactAttestations: Sendable, Hashable, Codable {
            public var trustDomain: String?
            public var services: [String]?

            enum CodingKeys: String, CodingKey {
                case services
                case trustDomain = "trust_domain"
            }
        }

        enum CodingKeys: String, CodingKey {
            case website, codespaces, copilot, packages, storage, actions
            case actionsInbound = "actions_inbound"
            case artifactAttestations = "artifact_attestations"
        }
    }

    enum CodingKeys: String, CodingKey {
        case hooks, web, api, git, packages, pages, importer, actions, codespaces, dependabot, copilot, domains
        case verifiablePasswordAuthentication = "verifiable_password_authentication"
        case sshKeyFingerprints = "ssh_key_fingerprints"
        case sshKeys = "ssh_keys"
        case githubEnterpriseImporter = "github_enterprise_importer"
        case sharedIngress = "shared_ingress"
        case actionsMacOS = "actions_macos"
        case commitSigningKeys = "commit_signing_keys"
    }
}

/// An open source license, with its text and what it allows (`license`).
public struct License: Sendable, Hashable, Codable, Identifiable {
    /// Such as `mit`.
    public var key: String
    public var name: String
    /// Such as `MIT`.
    public var spdxID: String?
    public var url: URL?
    public var nodeID: String?
    /// The license's page on choosealicense.com.
    public var htmlURL: URL?
    public var description: String
    /// How to add the license to a project.
    public var implementation: String
    /// What the license allows, such as `commercial-use`.
    public var permissions: [String]
    /// What it requires, such as `include-copyright`.
    public var conditions: [String]
    /// What it rules out, such as `liability`.
    public var limitations: [String]
    /// The license text, with placeholders such as `[year]` and `[fullname]`.
    public var body: String
    /// Whether GitHub suggests it when creating a repository.
    public var featured: Bool

    public var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, name, url, description, implementation, permissions, conditions, limitations, body, featured
        case spdxID = "spdx_id"
        case nodeID = "node_id"
        case htmlURL = "html_url"
    }
}

/// A `.gitignore` template (`gitignore-template`).
public struct GitignoreTemplate: Sendable, Hashable, Codable {
    /// Such as `Swift`.
    public var name: String
    /// The file's content.
    public var source: String
}

/// A code of conduct, with its text (`code-of-conduct`).
public struct CodeOfConduct: Sendable, Hashable, Codable, Identifiable {
    /// Such as `contributor_covenant`.
    public var key: String
    public var name: String
    public var url: URL?
    public var htmlURL: URL?
    /// The text, with placeholders such as `[INSERT EMAIL ADDRESS]`.
    public var body: String?

    public var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, name, url, body
        case htmlURL = "html_url"
    }
}

/// How ``MetaAPI/renderMarkdown(_:mode:context:)`` reads its text.
public struct MarkdownMode: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Plain Markdown, like a `README` file.
    public static let markdown: Self = "markdown"
    /// GitHub Flavored Markdown with links for references and mentions, like a comment.
    public static let gfm: Self = "gfm"
}
