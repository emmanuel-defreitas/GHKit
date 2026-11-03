import Foundation

// Files, archives, forks, and templates.
extension RepositoriesAPI {
    // MARK: Contents

    /// A file, or a directory's entries. `GET /repos/{owner}/{repo}/contents/{path}`
    /// - Parameters:
    ///   - path: Such as `Sources/App.swift`. Empty for the repository root.
    ///   - ref: A branch, tag, or commit. Defaults to the default branch.
    public func contents(
        _ owner: String, _ name: String, at path: String = "", ref: String? = nil
    ) async throws(GitHubError) -> Contents {
        try await client.value(GitHubRequest(.get, contentsPath(owner, name, path), query: .query(("ref", ref))))
    }

    /// A file's raw bytes. Works for files up to 100 MB. `GET /repos/{owner}/{repo}/contents/{path}`
    public func rawContents(
        _ owner: String, _ name: String, at path: String, ref: String? = nil
    ) async throws(GitHubError) -> Data {
        try await client.value(
            GitHubRequest(
                method: .get, target: .path(contentsPath(owner, name, path)), query: .query(("ref", ref)),
                headers: ["Accept": "application/vnd.github.raw+json"], decode: { $0 }))
    }

    /// Creates a file, or replaces one when `change.sha` is set. `PUT /repos/{owner}/{repo}/contents/{path}`
    @discardableResult
    public func writeFile(
        _ change: FileChange, to path: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> FileCommit {
        try await client.value(GitHubRequest(.put, contentsPath(owner, name, path), body: change))
    }

    /// Deletes a file. `DELETE /repos/{owner}/{repo}/contents/{path}`
    /// - Parameter sha: The file's current blob SHA.
    @discardableResult
    public func deleteFile(
        _ path: String, sha: String, message: String, in owner: String, _ name: String, branch: String? = nil,
        committer: GitActor? = nil, author: GitActor? = nil
    ) async throws(GitHubError) -> FileCommit {
        struct Body: Encodable, Sendable {
            let message: String
            let sha: String
            let branch: String?
            let committer: GitActor?
            let author: GitActor?
        }
        return try await client.value(
            GitHubRequest(
                .delete, contentsPath(owner, name, path),
                body: Body(message: message, sha: sha, branch: branch, committer: committer, author: author)))
    }

    /// The README, from the root or from a directory.
    /// `GET /repos/{owner}/{repo}/readme`, `GET /repos/{owner}/{repo}/readme/{dir}`
    public func readme(
        _ owner: String, _ name: String, in directory: String? = nil, ref: String? = nil
    ) async throws(GitHubError) -> RepositoryContent {
        let suffix = directory.map { "/readme/\(escapePath($0))" } ?? "/readme"
        return try await client.value(GitHubRequest(.get, path(owner, name, suffix), query: .query(("ref", ref))))
    }

    /// The license file and the license GitHub detected. `GET /repos/{owner}/{repo}/license`
    public func license(_ owner: String, _ name: String, ref: String? = nil) async throws(GitHubError) -> RepositoryLicense {
        try await client.value(GitHubRequest(.get, path(owner, name, "/license"), query: .query(("ref", ref))))
    }

    /// Syntax errors in the CODEOWNERS file. Empty when the file is valid. `GET /repos/{owner}/{repo}/codeowners/errors`
    public func codeownersErrors(_ owner: String, _ name: String, ref: String? = nil) async throws(GitHubError) -> [CodeownersError] {
        struct Response: Decodable, Sendable { let errors: [CodeownersError] }
        let response: Response = try await client.value(
            GitHubRequest(.get, path(owner, name, "/codeowners/errors"), query: .query(("ref", ref))))
        return response.errors
    }

    /// Downloads a source archive. GitHub redirects to the file, and URLSession follows.
    /// `GET /repos/{owner}/{repo}/tarball/{ref}`, `GET /repos/{owner}/{repo}/zipball/{ref}`
    /// - Parameter ref: Defaults to the default branch.
    public func archive(
        _ owner: String, _ name: String, format: ArchiveFormat = .zipball, ref: String? = nil
    ) async throws(GitHubError) -> Data {
        let suffix = "/\(format.rawValue)" + (ref.map { "/\(escapePath($0))" } ?? "")
        return try await client.value(GitHubRequest(method: .get, target: .path(path(owner, name, suffix)), decode: { $0 }))
    }

    private func contentsPath(_ owner: String, _ name: String, _ filePath: String) -> String {
        path(owner, name, "/contents/\(escapePath(filePath))")
    }

    // MARK: Forks and templates

    /// Forks of a repository. `GET /repos/{owner}/{repo}/forks`
    public func forks(_ owner: String, _ name: String, sort: ForkSort = .newest, perPage: Int = 100) -> Paginated<Repository> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/forks"), query: .query(("sort", sort), ("per_page", perPage))))
    }

    /// Forks a repository. GitHub copies it in the background, so it may take a moment to appear.
    /// `POST /repos/{owner}/{repo}/forks`
    /// - Parameters:
    ///   - org: Forks into this organization instead of the signed-in user's account.
    ///   - newName: Names the fork differently.
    ///   - defaultBranchOnly: Copies only the default branch.
    @discardableResult
    public func fork(
        _ owner: String, _ name: String, into org: String? = nil, as newName: String? = nil, defaultBranchOnly: Bool? = nil
    ) async throws(GitHubError) -> Repository {
        struct Body: Encodable, Sendable {
            let organization: String?
            let name: String?
            let defaultBranchOnly: Bool?
            enum CodingKeys: String, CodingKey {
                case organization, name
                case defaultBranchOnly = "default_branch_only"
            }
        }
        return try await client.value(
            GitHubRequest(
                .post, path(owner, name, "/forks"),
                body: Body(organization: org, name: newName, defaultBranchOnly: defaultBranchOnly)))
    }

    /// Brings a fork's branch up to date with its upstream. `POST /repos/{owner}/{repo}/merge-upstream`
    @discardableResult
    public func syncWithUpstream(_ owner: String, _ name: String, branch: String) async throws(GitHubError) -> MergeUpstreamResult {
        struct Body: Encodable, Sendable { let branch: String }
        return try await client.value(GitHubRequest(.post, path(owner, name, "/merge-upstream"), body: Body(branch: branch)))
    }

    /// Creates a repository from a template repository. `POST /repos/{template_owner}/{template_repo}/generate`
    @discardableResult
    public func create(
        _ repository: NewRepositoryFromTemplate, fromTemplate owner: String, _ name: String
    ) async throws(GitHubError) -> Repository {
        try await client.value(GitHubRequest(.post, path(owner, name, "/generate"), body: repository))
    }
}

/// Percent-encodes each segment of a slash-separated path, keeping the slashes.
func escapePath(_ path: String) -> String {
    path.split(separator: "/", omittingEmptySubsequences: false).map { escape(String($0)) }.joined(separator: "/")
}
