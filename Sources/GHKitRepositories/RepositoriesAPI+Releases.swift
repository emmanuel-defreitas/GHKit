import Foundation
import GHKitCore

// Releases, release notes, and release assets.
extension RepositoriesAPI {
    // MARK: Releases

    /// A repository's releases, newest first. Drafts appear only for people with push access.
    /// `GET /repos/{owner}/{repo}/releases`
    public func releases(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<Release> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/releases"), query: .query(("per_page", perPage))))
    }

    /// One release. `GET /repos/{owner}/{repo}/releases/{release_id}`
    public func release(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> Release {
        try await client.value(GitHubRequest(.get, path(owner, name, "/releases/\(id)")))
    }

    /// The latest published full release, ignoring drafts and prereleases. `GET /repos/{owner}/{repo}/releases/latest`
    public func latestRelease(_ owner: String, _ name: String) async throws(GitHubError) -> Release {
        try await client.value(GitHubRequest(.get, path(owner, name, "/releases/latest")))
    }

    /// The published release for a tag. `GET /repos/{owner}/{repo}/releases/tags/{tag}`
    public func release(tag: String, in owner: String, _ name: String) async throws(GitHubError) -> Release {
        try await client.value(GitHubRequest(.get, path(owner, name, "/releases/tags/\(escapePath(tag))")))
    }

    /// Creates a release, and its tag if needed. `POST /repos/{owner}/{repo}/releases`
    @discardableResult
    public func createRelease(_ release: NewRelease, in owner: String, _ name: String) async throws(GitHubError) -> Release {
        try await client.value(GitHubRequest(.post, path(owner, name, "/releases"), body: release))
    }

    /// Changes a release. Set ``ReleaseUpdate/isDraft`` to `false` to publish a draft.
    /// `PATCH /repos/{owner}/{repo}/releases/{release_id}`
    @discardableResult
    public func updateRelease(
        id: Int, in owner: String, _ name: String, _ changes: ReleaseUpdate
    ) async throws(GitHubError) -> Release {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/releases/\(id)"), body: changes))
    }

    /// Deletes a release. Its tag stays. `DELETE /repos/{owner}/{repo}/releases/{release_id}`
    public func deleteRelease(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/releases/\(id)")))
    }

    /// Writes release notes from the pull requests merged since the previous release, without saving anything.
    /// `POST /repos/{owner}/{repo}/releases/generate-notes`
    /// - Parameters:
    ///   - target: A branch or SHA for the tag. Required when the tag doesn't exist yet.
    ///   - previousTag: Where the notes start. Defaults to the previous release.
    ///   - configurationFile: Defaults to `.github/release.yml`.
    public func generateReleaseNotes(
        for tag: String, in owner: String, _ name: String, target: String? = nil, previousTag: String? = nil,
        configurationFile: String? = nil
    ) async throws(GitHubError) -> ReleaseNotes {
        struct Body: Encodable, Sendable {
            let tagName: String
            let targetCommitish: String?
            let previousTagName: String?
            let configurationFilePath: String?
            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case targetCommitish = "target_commitish"
                case previousTagName = "previous_tag_name"
                case configurationFilePath = "configuration_file_path"
            }
        }
        let body = Body(tagName: tag, targetCommitish: target, previousTagName: previousTag, configurationFilePath: configurationFile)
        return try await client.value(GitHubRequest(.post, path(owner, name, "/releases/generate-notes"), body: body))
    }

    // MARK: Assets

    /// A release's assets. `GET /repos/{owner}/{repo}/releases/{release_id}/assets`
    public func releaseAssets(of releaseID: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<ReleaseAsset> {
        client.paginate(
            GitHubRequest(.get, path(owner, name, "/releases/\(releaseID)/assets"), query: .query(("per_page", perPage))))
    }

    /// One asset's details. `GET /repos/{owner}/{repo}/releases/assets/{asset_id}`
    public func releaseAsset(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> ReleaseAsset {
        try await client.value(GitHubRequest(.get, path(owner, name, "/releases/assets/\(id)")))
    }

    /// Downloads an asset's file. Works for private repositories, unlike ``ReleaseAsset/browserDownloadURL``.
    /// `GET /repos/{owner}/{repo}/releases/assets/{asset_id}` with `Accept: application/octet-stream`
    public func downloadReleaseAsset(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> Data {
        try await client.value(
            GitHubRequest(
                method: .get, target: .path(path(owner, name, "/releases/assets/\(id)")),
                headers: ["Accept": "application/octet-stream"], decode: { $0 }))
    }

    /// Renames or relabels an asset. `PATCH /repos/{owner}/{repo}/releases/assets/{asset_id}`
    @discardableResult
    public func updateReleaseAsset(
        id: Int, in owner: String, _ name: String, fileName: String? = nil, label: String? = nil
    ) async throws(GitHubError) -> ReleaseAsset {
        struct Body: Encodable, Sendable {
            let name: String?
            let label: String?
        }
        return try await client.value(
            GitHubRequest(.patch, path(owner, name, "/releases/assets/\(id)"), body: Body(name: fileName, label: label)))
    }

    /// Deletes an asset. `DELETE /repos/{owner}/{repo}/releases/assets/{asset_id}`
    public func deleteReleaseAsset(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/releases/assets/\(id)")))
    }

    /// Uploads a file to a release, using the release's own upload address.
    /// `POST {upload_url}` on the uploads host, such as `uploads.github.com`
    /// - Parameters:
    ///   - fileName: Must be unique within the release.
    ///   - label: A short description shown in place of the file name.
    @discardableResult
    public func uploadReleaseAsset(
        _ data: Data, fileName: String, label: String? = nil, contentType: String = "application/octet-stream", to release: Release
    ) async throws(GitHubError) -> ReleaseAsset {
        let template = release.uploadURL
        let address = template.firstIndex(of: "{").map { String(template[..<$0]) } ?? template
        guard let url = URL(string: address) else { throw .invalidRequest("Invalid upload URL: \(template)") }
        return try await upload(data, fileName: fileName, label: label, contentType: contentType, to: url)
    }

    /// Uploads a file to a release by ID. `POST /repos/{owner}/{repo}/releases/{release_id}/assets` on the uploads host
    @discardableResult
    public func uploadReleaseAsset(
        _ data: Data, fileName: String, label: String? = nil, contentType: String = "application/octet-stream",
        toRelease releaseID: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> ReleaseAsset {
        let base = client.configuration.server.uploadsURL
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw .invalidRequest("Invalid uploads URL: \(base)")
        }
        var basePath = components.percentEncodedPath
        if basePath.hasSuffix("/") { basePath.removeLast() }
        components.percentEncodedPath = basePath + path(owner, name, "/releases/\(releaseID)/assets")
        guard let url = components.url else { throw .invalidRequest("Invalid uploads URL: \(components)") }
        return try await upload(data, fileName: fileName, label: label, contentType: contentType, to: url)
    }

    private func upload(
        _ data: Data, fileName: String, label: String?, contentType: String, to url: URL
    ) async throws(GitHubError) -> ReleaseAsset {
        try await client.value(
            GitHubRequest(
                method: .post, target: .url(url), query: .query(("name", fileName), ("label", label)),
                body: .raw(data, contentType: contentType)
            ) { data in try GitHubJSON.decoder().decode(ReleaseAsset.self, from: data) })
    }
}
