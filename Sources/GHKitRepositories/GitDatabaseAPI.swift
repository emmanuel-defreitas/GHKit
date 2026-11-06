import Foundation
import GHKitCore

extension RepositoriesAPI {
    /// The Git objects and references of one repository, for building commits without a clone.
    ///
    ///     let git = github.repositories.git("octocat", "Hello-World")
    ///     let head = try await git.ref("heads/main")
    ///     let parent = try await git.commit(head.object.sha)
    ///     let tree = try await git.createTree([.file("README.md", content: "Hello")], base: parent.tree.sha)
    ///     let commit = try await git.createCommit(NewGitCommit(message: "Update README", tree: tree.sha, parents: [parent.sha]))
    ///     try await git.updateRef("heads/main", to: commit.sha)
    public func git(_ owner: String, _ name: String) -> GitDatabaseAPI {
        GitDatabaseAPI(client: client, owner: owner, name: name)
    }
}

/// A repository's Git objects (blobs, trees, commits, and annotated tags) and references.
/// Reach it with `github.repositories.git(owner, name)`.
///
/// To change files in one commit: create a tree on top of the current one, create a commit that points to it,
/// then move the branch with ``updateRef(_:to:force:)``.
///
/// Part of the `GHKitRepositories` library.
public struct GitDatabaseAPI: Sendable {
    let client: GitHubClient
    public let owner: String
    public let name: String

    private func path(_ rest: String) -> String {
        "/repos/\(escape(owner))/\(escape(name))/git\(rest)"
    }

    /// A reference name as the `/git/ref` paths want it: `heads/main` rather than `refs/heads/main`.
    private func refPath(_ ref: String) -> String {
        escapePath(ref.hasPrefix("refs/") ? String(ref.dropFirst(5)) : ref)
    }

    // MARK: Blobs

    /// One blob, with its content. `GET /repos/{owner}/{repo}/git/blobs/{file_sha}`
    public func blob(_ sha: String) async throws(GitHubError) -> GitBlob {
        try await client.value(GitHubRequest(.get, path("/blobs/\(escape(sha))")))
    }

    /// Stores file content as a blob, for use in ``createTree(_:base:)``. `POST /repos/{owner}/{repo}/git/blobs`
    /// - Returns: The new blob's SHA and URL.
    @discardableResult
    public func createBlob(_ content: Data) async throws(GitHubError) -> GitCommit.Pointer {
        try await client.value(
            GitHubRequest(.post, path("/blobs"), body: ["content": content.base64EncodedString(), "encoding": "base64"]))
    }

    /// Stores text as a UTF-8 blob. `POST /repos/{owner}/{repo}/git/blobs`
    @discardableResult
    public func createBlob(text: String) async throws(GitHubError) -> GitCommit.Pointer {
        try await client.value(GitHubRequest(.post, path("/blobs"), body: ["content": text, "encoding": "utf-8"]))
    }

    // MARK: Trees

    /// One tree, the files and folders at one level, or every level when `recursive` is set.
    /// `GET /repos/{owner}/{repo}/git/trees/{tree_sha}`
    ///
    /// A recursive listing stops at 100,000 entries or 7 MB; ``GitTree/truncated`` says when it did.
    /// - Parameter sha: A tree SHA, or a branch or tag name.
    public func tree(_ sha: String, recursive: Bool = false) async throws(GitHubError) -> GitTree {
        try await client.value(
            GitHubRequest(.get, path("/trees/\(escapePath(sha))"), query: recursive ? [URLQueryItem(name: "recursive", value: "1")] : []))
    }

    /// Creates a tree. With `base`, the entries change that tree; without it, they're the whole tree.
    /// `POST /repos/{owner}/{repo}/git/trees`
    /// - Parameter base: The SHA of the tree to start from, usually the current commit's tree.
    @discardableResult
    public func createTree(_ entries: [NewGitTreeEntry], base: String? = nil) async throws(GitHubError) -> GitTree {
        struct Body: Encodable, Sendable {
            let tree: [NewGitTreeEntry]
            let baseTree: String?

            enum CodingKeys: String, CodingKey {
                case tree
                case baseTree = "base_tree"
            }
        }
        return try await client.value(GitHubRequest(.post, path("/trees"), body: Body(tree: entries, baseTree: base)))
    }

    // MARK: Commits

    /// One commit object. `GET /repos/{owner}/{repo}/git/commits/{commit_sha}`
    ///
    /// For changed files and GitHub accounts, use ``RepositoriesAPI/commit(_:in:_:)``.
    public func commit(_ sha: String) async throws(GitHubError) -> GitCommit {
        try await client.value(GitHubRequest(.get, path("/commits/\(escape(sha))")))
    }

    /// Creates a commit. It isn't on any branch until a reference points to it. `POST /repos/{owner}/{repo}/git/commits`
    @discardableResult
    public func createCommit(_ commit: NewGitCommit) async throws(GitHubError) -> GitCommit {
        try await client.value(GitHubRequest(.post, path("/commits"), body: commit))
    }

    // MARK: References

    /// One branch or tag reference. `GET /repos/{owner}/{repo}/git/ref/{ref}`
    /// - Parameter ref: Such as `heads/main` or `tags/v1.0`. A `refs/` prefix is dropped.
    public func ref(_ ref: String) async throws(GitHubError) -> GitReference {
        try await client.value(GitHubRequest(.get, path("/ref/\(refPath(ref))")))
    }

    /// References whose names start with `prefix`, such as `heads/feature` or `tags/v1`.
    /// `GET /repos/{owner}/{repo}/git/matching-refs/{ref}`
    ///
    /// Pass `heads` or `tags` for every branch or tag. An exact name that matches nothing returns an empty list.
    public func matchingRefs(_ prefix: String) -> Paginated<GitReference> {
        client.paginate(GitHubRequest(.get, path("/matching-refs/\(refPath(prefix))")))
    }

    /// Creates a branch or tag reference. `POST /repos/{owner}/{repo}/git/refs`
    /// - Parameter ref: The full name, such as `refs/heads/feature`. A name without `refs/` gets it added.
    @discardableResult
    public func createRef(_ ref: String, at sha: String) async throws(GitHubError) -> GitReference {
        let full = ref.hasPrefix("refs/") ? ref : "refs/\(ref)"
        return try await client.value(GitHubRequest(.post, path("/refs"), body: ["ref": full, "sha": sha]))
    }

    /// Points a reference at another commit. `PATCH /repos/{owner}/{repo}/git/refs/{ref}`
    /// - Parameter force: Allows a move that isn't a fast-forward, which drops commits from the branch.
    @discardableResult
    public func updateRef(_ ref: String, to sha: String, force: Bool = false) async throws(GitHubError) -> GitReference {
        struct Body: Encodable, Sendable {
            let sha: String
            let force: Bool
        }
        return try await client.value(GitHubRequest(.patch, path("/refs/\(refPath(ref))"), body: Body(sha: sha, force: force)))
    }

    /// Deletes a branch or tag reference. `DELETE /repos/{owner}/{repo}/git/refs/{ref}`
    public func deleteRef(_ ref: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path("/refs/\(refPath(ref))")))
    }

    // MARK: Tags

    /// One annotated tag object. `GET /repos/{owner}/{repo}/git/tags/{tag_sha}`
    public func tag(_ sha: String) async throws(GitHubError) -> GitTag {
        try await client.value(GitHubRequest(.get, path("/tags/\(escape(sha))")))
    }

    /// Creates an annotated tag object. To make it visible as a tag, also create a `refs/tags/…` reference to it
    /// with ``createRef(_:at:)``. `POST /repos/{owner}/{repo}/git/tags`
    @discardableResult
    public func createTag(_ tag: NewGitTag) async throws(GitHubError) -> GitTag {
        try await client.value(GitHubRequest(.post, path("/tags"), body: tag))
    }
}
