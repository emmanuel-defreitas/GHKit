import Foundation
import GHKitCore

/// A release of a repository (`release`).
public struct Release: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var tagName: String
    /// The branch or commit the tag was created from.
    public var targetCommitish: String
    public var name: String?
    /// Markdown release notes.
    public var body: String?
    public var bodyHTML: String?
    public var bodyText: String?
    public var isDraft: Bool
    public var isPrerelease: Bool
    /// Whether the release's tag and assets are locked.
    public var isImmutable: Bool?
    public var author: SimpleUser
    public var assets: [ReleaseAsset]
    public var url: URL
    public var htmlURL: URL
    public var assetsURL: URL
    /// A URI template such as `https://uploads.github.com/repos/o/r/releases/1/assets{?name,label}`.
    public var uploadURL: String
    public var tarballURL: URL?
    public var zipballURL: URL?
    public var discussionURL: URL?
    public var mentionsCount: Int?
    public var reactions: ReactionSummary?
    public var createdAt: Date
    /// `nil` for drafts.
    public var publishedAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, body, author, assets, url, reactions
        case nodeID = "node_id"
        case tagName = "tag_name"
        case targetCommitish = "target_commitish"
        case bodyHTML = "body_html"
        case bodyText = "body_text"
        case isDraft = "draft"
        case isPrerelease = "prerelease"
        case isImmutable = "immutable"
        case htmlURL = "html_url"
        case assetsURL = "assets_url"
        case uploadURL = "upload_url"
        case tarballURL = "tarball_url"
        case zipballURL = "zipball_url"
        case discussionURL = "discussion_url"
        case mentionsCount = "mentions_count"
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case updatedAt = "updated_at"
    }
}

/// A file attached to a release (`release-asset`).
public struct ReleaseAsset: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    /// A short description shown in place of the file name.
    public var label: String?
    public var state: ReleaseAssetState
    public var contentType: String
    /// In bytes.
    public var size: Int
    /// Such as `sha256:…`.
    public var digest: String?
    public var downloadCount: Int
    public var uploader: SimpleUser?
    public var url: URL
    /// The public download link. Private repositories need ``RepositoriesAPI/downloadReleaseAsset(id:in:_:)`` instead.
    public var browserDownloadURL: URL
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, label, state, size, digest, uploader, url
        case nodeID = "node_id"
        case contentType = "content_type"
        case downloadCount = "download_count"
        case browserDownloadURL = "browser_download_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Whether an asset has finished uploading.
public struct ReleaseAssetState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let uploaded: Self = "uploaded"
    public static let open: Self = "open"
}

/// Release notes GitHub wrote from merged pull requests (`release-notes-content`).
public struct ReleaseNotes: Sendable, Hashable, Codable {
    public var name: String
    /// Markdown.
    public var body: String
}

/// Whether a release becomes the repository's latest release.
public struct LatestReleasePolicy: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let latest: Self = "true"
    public static let notLatest: Self = "false"
    /// Picks the latest release by creation date and semantic version.
    public static let legacy: Self = "legacy"
}

// MARK: - Inputs

/// A new release.
public struct NewRelease: Sendable, Hashable, Encodable {
    /// The tag to release. GitHub creates it from ``targetCommitish`` if it doesn't exist.
    public var tagName: String
    /// A branch or commit SHA. Defaults to the default branch.
    public var targetCommitish: String?
    public var name: String?
    public var body: String?
    public var isDraft: Bool?
    public var isPrerelease: Bool?
    /// Starts a discussion in this existing category.
    public var discussionCategoryName: String?
    /// Fills in the name and notes GitHub would generate. A ``name`` or ``body`` you pass is kept.
    public var generateReleaseNotes: Bool?
    public var makeLatest: LatestReleasePolicy?

    public init(
        tagName: String, targetCommitish: String? = nil, name: String? = nil, body: String? = nil, isDraft: Bool? = nil,
        isPrerelease: Bool? = nil, discussionCategoryName: String? = nil, generateReleaseNotes: Bool? = nil,
        makeLatest: LatestReleasePolicy? = nil
    ) {
        self.tagName = tagName
        self.targetCommitish = targetCommitish
        self.name = name
        self.body = body
        self.isDraft = isDraft
        self.isPrerelease = isPrerelease
        self.discussionCategoryName = discussionCategoryName
        self.generateReleaseNotes = generateReleaseNotes
        self.makeLatest = makeLatest
    }

    enum CodingKeys: String, CodingKey {
        case name, body
        case tagName = "tag_name"
        case targetCommitish = "target_commitish"
        case isDraft = "draft"
        case isPrerelease = "prerelease"
        case discussionCategoryName = "discussion_category_name"
        case generateReleaseNotes = "generate_release_notes"
        case makeLatest = "make_latest"
    }
}

/// Changes to a release. Values you leave `nil` keep their current value.
public struct ReleaseUpdate: Sendable, Hashable, Encodable {
    public var tagName: String?
    public var targetCommitish: String?
    public var name: String?
    public var body: String?
    /// `false` publishes a draft.
    public var isDraft: Bool?
    public var isPrerelease: Bool?
    public var discussionCategoryName: String?
    public var makeLatest: LatestReleasePolicy?

    public init(
        tagName: String? = nil, targetCommitish: String? = nil, name: String? = nil, body: String? = nil, isDraft: Bool? = nil,
        isPrerelease: Bool? = nil, discussionCategoryName: String? = nil, makeLatest: LatestReleasePolicy? = nil
    ) {
        self.tagName = tagName
        self.targetCommitish = targetCommitish
        self.name = name
        self.body = body
        self.isDraft = isDraft
        self.isPrerelease = isPrerelease
        self.discussionCategoryName = discussionCategoryName
        self.makeLatest = makeLatest
    }

    enum CodingKeys: String, CodingKey {
        case name, body
        case tagName = "tag_name"
        case targetCommitish = "target_commitish"
        case isDraft = "draft"
        case isPrerelease = "prerelease"
        case discussionCategoryName = "discussion_category_name"
        case makeLatest = "make_latest"
    }
}
