import Foundation
import GHKitCore

/// A repository's GitHub Pages site (`page`).
public struct PagesSite: Sendable, Hashable, Codable {
    public var url: URL
    public var status: PagesBuildStatus?
    /// The custom domain, such as `docs.example.com`.
    public var cname: String?
    /// Whether the custom domain is verified, which stops other accounts from claiming it.
    public var protectedDomainState: PagesDomainState?
    /// When an unverified custom domain will be removed.
    public var pendingDomainUnverifiedAt: Date?
    public var hasCustom404: Bool
    public var htmlURL: URL?
    public var buildType: PagesBuildType?
    /// The branch and folder published, for ``PagesBuildType/legacy`` builds.
    public var source: PagesSource?
    /// Whether the site is visible to everyone. Private sites need GitHub Enterprise Cloud.
    public var isPublic: Bool
    public var httpsCertificate: PagesCertificate?
    public var httpsEnforced: Bool?

    enum CodingKeys: String, CodingKey {
        case url, status, cname, source
        case protectedDomainState = "protected_domain_state"
        case pendingDomainUnverifiedAt = "pending_domain_unverified_at"
        case hasCustom404 = "custom_404"
        case htmlURL = "html_url"
        case buildType = "build_type"
        case isPublic = "public"
        case httpsCertificate = "https_certificate"
        case httpsEnforced = "https_enforced"
    }
}

/// The state of a Pages site or build.
public struct PagesBuildStatus: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let queued: Self = "queued"
    public static let building: Self = "building"
    public static let built: Self = "built"
    public static let errored: Self = "errored"
}

/// How a Pages site is built.
public struct PagesBuildType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Built by GitHub from a branch and folder.
    public static let legacy: Self = "legacy"
    /// Built and deployed by a GitHub Actions workflow.
    public static let workflow: Self = "workflow"
}

/// Whether a custom domain is verified for the account.
public struct PagesDomainState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pending: Self = "pending"
    public static let verified: Self = "verified"
    public static let unverified: Self = "unverified"
}

/// The branch and folder a Pages site publishes from (`pages-source-hash`).
public struct PagesSource: Sendable, Hashable, Codable {
    public var branch: String
    /// `/` or `/docs`.
    public var path: String

    public init(branch: String, path: String = "/") {
        self.branch = branch
        self.path = path
    }
}

/// The TLS certificate for a Pages site's custom domain (`pages-https-certificate`).
public struct PagesCertificate: Sendable, Hashable, Codable {
    /// Such as `authorization_pending`, `issued`, or `approved`.
    public var state: String
    public var description: String
    public var domains: [String]
    public var expiresAt: CalendarDate?

    enum CodingKeys: String, CodingKey {
        case state, description, domains
        case expiresAt = "expires_at"
    }
}

/// Changes to a Pages site. `nil` leaves a setting as it is.
public struct PagesSiteUpdate: Sendable, Hashable, Encodable {
    public var customDomain: CustomDomain?
    public var httpsEnforced: Bool?
    public var buildType: PagesBuildType?
    public var source: PagesSource?

    /// A custom domain change.
    public enum CustomDomain: Sendable, Hashable {
        case set(String)
        case remove
    }

    public init(
        customDomain: CustomDomain? = nil, httpsEnforced: Bool? = nil, buildType: PagesBuildType? = nil, source: PagesSource? = nil
    ) {
        self.customDomain = customDomain
        self.httpsEnforced = httpsEnforced
        self.buildType = buildType
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case cname, source
        case httpsEnforced = "https_enforced"
        case buildType = "build_type"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch customDomain {
        case .set(let domain): try c.encode(domain, forKey: .cname)
        // GitHub removes the custom domain when `cname` is null.
        case .remove: try c.encodeNil(forKey: .cname)
        case nil: break
        }
        try c.encodeIfPresent(httpsEnforced, forKey: .httpsEnforced)
        try c.encodeIfPresent(buildType, forKey: .buildType)
        try c.encodeIfPresent(source, forKey: .source)
    }
}

/// One build of a Pages site (`page-build`).
public struct PagesBuild: Sendable, Hashable, Codable {
    public var url: URL
    public var status: PagesBuildStatus
    /// Why the build failed, or `nil`.
    public var errorMessage: String?
    public var pusher: SimpleUser?
    /// The SHA that was built.
    public var commit: String
    /// Milliseconds.
    public var duration: Int
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case url, status, error, pusher, commit, duration
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    private struct BuildError: Codable {
        var message: String?
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decode(URL.self, forKey: .url)
        status = try c.decode(PagesBuildStatus.self, forKey: .status)
        errorMessage = try c.decodeIfPresent(BuildError.self, forKey: .error)?.message
        pusher = try? c.decodeIfPresent(SimpleUser.self, forKey: .pusher)
        commit = try c.decode(String.self, forKey: .commit)
        duration = try c.decode(Int.self, forKey: .duration)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(url, forKey: .url)
        try c.encode(status, forKey: .status)
        try c.encode(BuildError(message: errorMessage), forKey: .error)
        try c.encodeIfPresent(pusher, forKey: .pusher)
        try c.encode(commit, forKey: .commit)
        try c.encode(duration, forKey: .duration)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

/// A queued Pages build (`page-build-status`).
public struct QueuedPagesBuild: Sendable, Hashable, Codable {
    /// Fetch this URL to follow the build, or use ``RepositoriesAPI/latestPagesBuild(_:_:)``.
    public var url: URL
    public var status: PagesBuildStatus
}

/// A Pages deployment from a workflow artifact (`page-deployment`).
public struct PagesDeployment: Sendable, Hashable, Codable, Identifiable {
    /// A number or a SHA, depending on how the deployment was made.
    public var id: String
    public var statusURL: URL
    /// The site's address. GitHub may send it without a scheme.
    public var pageURL: String
    /// The preview address, for preview deployments.
    public var previewURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case statusURL = "status_url"
        case pageURL = "page_url"
        case previewURL = "preview_url"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? c.decode(Int.self, forKey: .id) {
            id = String(number)
        } else {
            id = try c.decode(String.self, forKey: .id)
        }
        statusURL = try c.decode(URL.self, forKey: .statusURL)
        pageURL = try c.decode(String.self, forKey: .pageURL)
        previewURL = try c.decodeIfPresent(String.self, forKey: .previewURL)
    }
}

/// The progress of a Pages deployment (`pages-deployment-status`).
public struct PagesDeploymentState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let inProgress: Self = "deployment_in_progress"
    public static let syncingFiles: Self = "syncing_files"
    public static let finishedFileSync: Self = "finished_file_sync"
    public static let updatingPages: Self = "updating_pages"
    public static let purgingCDN: Self = "purging_cdn"
    public static let cancelled: Self = "deployment_cancelled"
    public static let failed: Self = "deployment_failed"
    public static let contentFailed: Self = "deployment_content_failed"
    public static let attemptError: Self = "deployment_attempt_error"
    public static let lost: Self = "deployment_lost"
    public static let succeeded: Self = "succeed"

    /// Whether the deployment has stopped, successfully or not.
    public var isFinished: Bool {
        [.cancelled, .failed, .contentFailed, .attemptError, .lost, .succeeded].contains(self)
    }
}

/// A Pages deployment to create from a workflow artifact.
public struct NewPagesDeployment: Sendable, Hashable, Encodable {
    /// The artifact holding a `.zip` or `.tar` of the site. Pass this or ``artifactURL``.
    public var artifactID: Int?
    public var artifactURL: URL?
    /// Defaults to `github-pages`.
    public var environment: String?
    /// A unique version for the build, usually the commit SHA.
    public var buildVersion: String
    /// The OIDC token issued by GitHub Actions for this deployment.
    public var oidcToken: String

    public init(artifactID: Int, buildVersion: String, oidcToken: String, environment: String? = nil) {
        self.artifactID = artifactID
        self.buildVersion = buildVersion
        self.oidcToken = oidcToken
        self.environment = environment
    }

    public init(artifactURL: URL, buildVersion: String, oidcToken: String, environment: String? = nil) {
        self.artifactURL = artifactURL
        self.buildVersion = buildVersion
        self.oidcToken = oidcToken
        self.environment = environment
    }

    enum CodingKeys: String, CodingKey {
        case environment
        case artifactID = "artifact_id"
        case artifactURL = "artifact_url"
        case buildVersion = "pages_build_version"
        case oidcToken = "oidc_token"
    }
}

/// DNS and HTTPS checks for a Pages site's custom domain (`pages-health-check`).
public struct PagesHealthCheck: Sendable, Hashable, Codable {
    public var domain: Domain?
    /// The `www` or apex counterpart of ``domain``.
    public var altDomain: Domain?

    enum CodingKeys: String, CodingKey {
        case domain
        case altDomain = "alt_domain"
    }

    /// The checks for one host name.
    public struct Domain: Sendable, Hashable, Codable {
        public var host: String
        public var uri: String
        public var nameservers: String
        public var dnsResolves: Bool
        public var isProxied: Bool?
        public var isCloudflareIP: Bool?
        public var isFastlyIP: Bool?
        public var isOldIPAddress: Bool?
        public var isARecord: Bool?
        public var hasCNAMERecord: Bool?
        public var hasMXRecordsPresent: Bool?
        public var isValidDomain: Bool
        public var isApexDomain: Bool
        public var shouldBeARecord: Bool?
        public var isCNAMEToGitHubUserDomain: Bool?
        public var isCNAMEToPagesDotGitHubDotCom: Bool?
        public var isCNAMEToFastly: Bool?
        public var isPointedToGitHubPagesIP: Bool?
        public var isNonGitHubPagesIPPresent: Bool?
        public var isPagesDomain: Bool
        public var isServedByPages: Bool?
        /// Whether the domain is set up correctly. See ``reason`` when it isn't.
        public var isValid: Bool
        public var reason: String?
        public var respondsToHTTPS: Bool
        public var enforcesHTTPS: Bool
        public var httpsError: String?
        public var isHTTPSEligible: Bool?
        public var caaError: String?

        enum CodingKeys: String, CodingKey {
            case host, uri, nameservers, reason
            case dnsResolves = "dns_resolves"
            case isProxied = "is_proxied"
            case isCloudflareIP = "is_cloudflare_ip"
            case isFastlyIP = "is_fastly_ip"
            case isOldIPAddress = "is_old_ip_address"
            case isARecord = "is_a_record"
            case hasCNAMERecord = "has_cname_record"
            case hasMXRecordsPresent = "has_mx_records_present"
            case isValidDomain = "is_valid_domain"
            case isApexDomain = "is_apex_domain"
            case shouldBeARecord = "should_be_a_record"
            case isCNAMEToGitHubUserDomain = "is_cname_to_github_user_domain"
            case isCNAMEToPagesDotGitHubDotCom = "is_cname_to_pages_dot_github_dot_com"
            case isCNAMEToFastly = "is_cname_to_fastly"
            case isPointedToGitHubPagesIP = "is_pointed_to_github_pages_ip"
            case isNonGitHubPagesIPPresent = "is_non_github_pages_ip_present"
            case isPagesDomain = "is_pages_domain"
            case isServedByPages = "is_served_by_pages"
            case isValid = "is_valid"
            case respondsToHTTPS = "responds_to_https"
            case enforcesHTTPS = "enforces_https"
            case httpsError = "https_error"
            case isHTTPSEligible = "is_https_eligible"
            case caaError = "caa_error"
        }
    }
}
