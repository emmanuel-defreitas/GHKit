import Foundation
import GHKitCore

/// Which merge methods a repository allows, and how merge commits read. `nil` leaves a setting as it is.
public struct MergeSettings: Sendable, Hashable, Encodable {
    public var allowMergeCommit: Bool?
    public var allowSquashMerge: Bool?
    public var allowRebaseMerge: Bool?
    public var allowAutoMerge: Bool?
    public var deleteBranchOnMerge: Bool?
    public var squashMergeCommitTitle: SquashMergeCommitTitle?
    public var squashMergeCommitMessage: SquashMergeCommitMessage?
    public var mergeCommitTitle: MergeCommitTitle?
    public var mergeCommitMessage: MergeCommitMessage?

    public init(
        allowMergeCommit: Bool? = nil, allowSquashMerge: Bool? = nil, allowRebaseMerge: Bool? = nil,
        allowAutoMerge: Bool? = nil, deleteBranchOnMerge: Bool? = nil,
        squashMergeCommitTitle: SquashMergeCommitTitle? = nil, squashMergeCommitMessage: SquashMergeCommitMessage? = nil,
        mergeCommitTitle: MergeCommitTitle? = nil, mergeCommitMessage: MergeCommitMessage? = nil
    ) {
        self.allowMergeCommit = allowMergeCommit
        self.allowSquashMerge = allowSquashMerge
        self.allowRebaseMerge = allowRebaseMerge
        self.allowAutoMerge = allowAutoMerge
        self.deleteBranchOnMerge = deleteBranchOnMerge
        self.squashMergeCommitTitle = squashMergeCommitTitle
        self.squashMergeCommitMessage = squashMergeCommitMessage
        self.mergeCommitTitle = mergeCommitTitle
        self.mergeCommitMessage = mergeCommitMessage
    }

    enum CodingKeys: String, CodingKey {
        case allowMergeCommit = "allow_merge_commit"
        case allowSquashMerge = "allow_squash_merge"
        case allowRebaseMerge = "allow_rebase_merge"
        case allowAutoMerge = "allow_auto_merge"
        case deleteBranchOnMerge = "delete_branch_on_merge"
        case squashMergeCommitTitle = "squash_merge_commit_title"
        case squashMergeCommitMessage = "squash_merge_commit_message"
        case mergeCommitTitle = "merge_commit_title"
        case mergeCommitMessage = "merge_commit_message"
    }
}

/// A repository to create.
public struct NewRepository: Sendable, Hashable, Encodable {
    public var name: String
    public var description: String?
    public var homepage: String?
    /// `.internal` only works for organization repositories in an enterprise.
    public var visibility: RepositoryVisibility?
    public var hasIssues: Bool?
    public var hasProjects: Bool?
    public var hasWiki: Bool?
    public var hasDiscussions: Bool?
    public var isTemplate: Bool?
    /// Gives this team access, for organization repositories.
    public var teamID: Int?
    /// Creates an initial commit with a README.
    public var autoInitialize: Bool?
    /// A template name from `GET /gitignore/templates`, such as `Swift`.
    public var gitignoreTemplate: String?
    /// A license key, such as `mit`.
    public var licenseTemplate: String?
    public var merge: MergeSettings
    /// Custom property values, for organization repositories.
    public var customProperties: [String: PropertyValue]?

    public init(
        name: String, description: String? = nil, homepage: String? = nil, visibility: RepositoryVisibility? = nil,
        hasIssues: Bool? = nil, hasProjects: Bool? = nil, hasWiki: Bool? = nil, hasDiscussions: Bool? = nil,
        isTemplate: Bool? = nil, teamID: Int? = nil, autoInitialize: Bool? = nil, gitignoreTemplate: String? = nil,
        licenseTemplate: String? = nil, merge: MergeSettings = MergeSettings(), customProperties: [String: PropertyValue]? = nil
    ) {
        self.name = name
        self.description = description
        self.homepage = homepage
        self.visibility = visibility
        self.hasIssues = hasIssues
        self.hasProjects = hasProjects
        self.hasWiki = hasWiki
        self.hasDiscussions = hasDiscussions
        self.isTemplate = isTemplate
        self.teamID = teamID
        self.autoInitialize = autoInitialize
        self.gitignoreTemplate = gitignoreTemplate
        self.licenseTemplate = licenseTemplate
        self.merge = merge
        self.customProperties = customProperties
    }

    enum CodingKeys: String, CodingKey {
        case name, description, homepage, visibility
        case isPrivate = "private"
        case hasIssues = "has_issues"
        case hasProjects = "has_projects"
        case hasWiki = "has_wiki"
        case hasDiscussions = "has_discussions"
        case isTemplate = "is_template"
        case teamID = "team_id"
        case autoInitialize = "auto_init"
        case gitignoreTemplate = "gitignore_template"
        case licenseTemplate = "license_template"
        case customProperties = "custom_properties"
    }

    public func encode(to encoder: any Encoder) throws {
        try merge.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(homepage, forKey: .homepage)
        if let visibility {
            // User repositories only understand `private`; organization repositories prefer `visibility`.
            try c.encode(visibility, forKey: .visibility)
            try c.encode(visibility == .private, forKey: .isPrivate)
        }
        try c.encodeIfPresent(hasIssues, forKey: .hasIssues)
        try c.encodeIfPresent(hasProjects, forKey: .hasProjects)
        try c.encodeIfPresent(hasWiki, forKey: .hasWiki)
        try c.encodeIfPresent(hasDiscussions, forKey: .hasDiscussions)
        try c.encodeIfPresent(isTemplate, forKey: .isTemplate)
        try c.encodeIfPresent(teamID, forKey: .teamID)
        try c.encodeIfPresent(autoInitialize, forKey: .autoInitialize)
        try c.encodeIfPresent(gitignoreTemplate, forKey: .gitignoreTemplate)
        try c.encodeIfPresent(licenseTemplate, forKey: .licenseTemplate)
        try c.encodeIfPresent(customProperties, forKey: .customProperties)
    }
}

/// Changes to a repository. `nil` leaves a field as it is.
public struct RepositoryUpdate: Sendable, Hashable, Encodable {
    public var name: String?
    public var description: String?
    public var homepage: String?
    public var visibility: RepositoryVisibility?
    public var defaultBranch: String?
    public var hasIssues: Bool?
    public var hasProjects: Bool?
    public var hasWiki: Bool?
    public var hasPullRequests: Bool?
    public var isTemplate: Bool?
    /// `true` archives the repository. You can't unarchive through the API.
    public var archived: Bool?
    public var allowForking: Bool?
    public var allowUpdateBranch: Bool?
    public var webCommitSignoffRequired: Bool?
    public var merge: MergeSettings
    /// Turns security features on or off.
    public var securityFeatures: [SecurityFeature: Bool]?

    public init(
        name: String? = nil, description: String? = nil, homepage: String? = nil, visibility: RepositoryVisibility? = nil,
        defaultBranch: String? = nil, hasIssues: Bool? = nil, hasProjects: Bool? = nil, hasWiki: Bool? = nil,
        hasPullRequests: Bool? = nil, isTemplate: Bool? = nil, archived: Bool? = nil, allowForking: Bool? = nil,
        allowUpdateBranch: Bool? = nil, webCommitSignoffRequired: Bool? = nil, merge: MergeSettings = MergeSettings(),
        securityFeatures: [SecurityFeature: Bool]? = nil
    ) {
        self.name = name
        self.description = description
        self.homepage = homepage
        self.visibility = visibility
        self.defaultBranch = defaultBranch
        self.hasIssues = hasIssues
        self.hasProjects = hasProjects
        self.hasWiki = hasWiki
        self.hasPullRequests = hasPullRequests
        self.isTemplate = isTemplate
        self.archived = archived
        self.allowForking = allowForking
        self.allowUpdateBranch = allowUpdateBranch
        self.webCommitSignoffRequired = webCommitSignoffRequired
        self.merge = merge
        self.securityFeatures = securityFeatures
    }

    enum CodingKeys: String, CodingKey {
        case name, description, homepage, visibility, archived
        case defaultBranch = "default_branch"
        case hasIssues = "has_issues"
        case hasProjects = "has_projects"
        case hasWiki = "has_wiki"
        case hasPullRequests = "has_pull_requests"
        case isTemplate = "is_template"
        case allowForking = "allow_forking"
        case allowUpdateBranch = "allow_update_branch"
        case webCommitSignoffRequired = "web_commit_signoff_required"
        case securityAndAnalysis = "security_and_analysis"
    }

    public func encode(to encoder: any Encoder) throws {
        try merge.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(homepage, forKey: .homepage)
        try c.encodeIfPresent(visibility, forKey: .visibility)
        try c.encodeIfPresent(defaultBranch, forKey: .defaultBranch)
        try c.encodeIfPresent(hasIssues, forKey: .hasIssues)
        try c.encodeIfPresent(hasProjects, forKey: .hasProjects)
        try c.encodeIfPresent(hasWiki, forKey: .hasWiki)
        try c.encodeIfPresent(hasPullRequests, forKey: .hasPullRequests)
        try c.encodeIfPresent(isTemplate, forKey: .isTemplate)
        try c.encodeIfPresent(archived, forKey: .archived)
        try c.encodeIfPresent(allowForking, forKey: .allowForking)
        try c.encodeIfPresent(allowUpdateBranch, forKey: .allowUpdateBranch)
        try c.encodeIfPresent(webCommitSignoffRequired, forKey: .webCommitSignoffRequired)
        try c.encodeIfPresent(securityFeatures.map(SecurityAndAnalysis.init), forKey: .securityAndAnalysis)
    }
}

// MARK: List filters

/// How to sort repository lists.
public enum RepositorySort: String, Sendable, Hashable, CustomStringConvertible {
    case created, updated, pushed
    case fullName = "full_name"
    public var description: String { rawValue }
}

/// Narrows an organization's repositories.
public enum OrganizationRepositoryType: String, Sendable, Hashable, CustomStringConvertible {
    case all, `public`, `private`, forks, sources, member
    public var description: String { rawValue }
}

/// Narrows a user's repositories.
public enum UserRepositoryType: String, Sendable, Hashable, CustomStringConvertible {
    case all, owner, member
    public var description: String { rawValue }
}

/// How the signed-in user relates to a repository.
public enum RepositoryAffiliation: String, Sendable, Hashable, CaseIterable {
    case owner, collaborator
    case organizationMember = "organization_member"
}

/// Narrows the signed-in user's repositories.
public struct RepositoryFilter: Sendable, Hashable {
    /// `nil` includes every visibility.
    public var visibility: RepositoryVisibility?
    /// Defaults to all three affiliations.
    public var affiliation: Set<RepositoryAffiliation>
    public var updatedSince: Date?
    public var updatedBefore: Date?

    public init(
        visibility: RepositoryVisibility? = nil, affiliation: Set<RepositoryAffiliation> = Set(RepositoryAffiliation.allCases),
        updatedSince: Date? = nil, updatedBefore: Date? = nil
    ) {
        self.visibility = visibility
        self.affiliation = affiliation
        self.updatedSince = updatedSince
        self.updatedBefore = updatedBefore
    }

    var query: [URLQueryItem] {
        .query(
            ("visibility", visibility),
            ("affiliation", RepositoryAffiliation.allCases.filter(affiliation.contains).map(\.rawValue).joined(separator: ",")),
            ("since", updatedSince?.ISO8601Format()), ("before", updatedBefore?.ISO8601Format()))
    }
}
