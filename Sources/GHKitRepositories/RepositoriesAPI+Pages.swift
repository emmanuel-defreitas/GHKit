import Foundation
import GHKitCore

// GitHub Pages sites, builds, deployments, and DNS health checks.
extension RepositoriesAPI {
    // MARK: Sites

    /// A repository's Pages site. `GET /repos/{owner}/{repo}/pages`
    /// - Throws: ``GitHubError`` with status 404 when the repository has no site.
    public func pagesSite(_ owner: String, _ name: String) async throws(GitHubError) -> PagesSite {
        try await client.value(GitHubRequest(.get, path(owner, name, "/pages")))
    }

    /// Publishes a Pages site from a branch and folder. `POST /repos/{owner}/{repo}/pages`
    @discardableResult
    public func createPagesSite(from source: PagesSource, in owner: String, _ name: String) async throws(GitHubError) -> PagesSite {
        try await createPagesSite(PagesSiteBody(buildType: .legacy, source: source), owner, name)
    }

    /// Creates a Pages site built by a GitHub Actions workflow, or from the default branch's root.
    /// `POST /repos/{owner}/{repo}/pages`
    @discardableResult
    public func createPagesSite(
        buildType: PagesBuildType = .workflow, in owner: String, _ name: String
    ) async throws(GitHubError) -> PagesSite {
        try await createPagesSite(PagesSiteBody(buildType: buildType, source: nil), owner, name)
    }

    private struct PagesSiteBody: Encodable, Sendable {
        let buildType: PagesBuildType
        let source: PagesSource?

        enum CodingKeys: String, CodingKey {
            case source
            case buildType = "build_type"
        }
    }

    private func createPagesSite(_ body: PagesSiteBody, _ owner: String, _ name: String) async throws(GitHubError) -> PagesSite {
        try await client.value(GitHubRequest(.post, path(owner, name, "/pages"), body: body))
    }

    /// Changes a Pages site's custom domain, HTTPS, or source. `PUT /repos/{owner}/{repo}/pages`
    public func updatePagesSite(_ owner: String, _ name: String, _ changes: PagesSiteUpdate) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, path(owner, name, "/pages"), body: changes))
    }

    /// Unpublishes a Pages site. `DELETE /repos/{owner}/{repo}/pages`
    public func deletePagesSite(_ owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/pages")))
    }

    /// DNS and HTTPS checks for the site's custom domain. `GET /repos/{owner}/{repo}/pages/health`
    /// - Returns: The checks, or `nil` while GitHub runs them (status 202). Try again shortly.
    public func pagesHealthCheck(_ owner: String, _ name: String) async throws(GitHubError) -> PagesHealthCheck? {
        try await client.valueUnlessAccepted(path(owner, name, "/pages/health"))
    }

    // MARK: Builds

    /// A site's builds, newest first. Only for ``PagesBuildType/legacy`` sites. `GET /repos/{owner}/{repo}/pages/builds`
    public func pagesBuilds(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<PagesBuild> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/pages/builds"), query: .query(("per_page", perPage))))
    }

    /// The most recent build. `GET /repos/{owner}/{repo}/pages/builds/latest`
    public func latestPagesBuild(_ owner: String, _ name: String) async throws(GitHubError) -> PagesBuild {
        try await client.value(GitHubRequest(.get, path(owner, name, "/pages/builds/latest")))
    }

    /// One build. `GET /repos/{owner}/{repo}/pages/builds/{build_id}`
    public func pagesBuild(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> PagesBuild {
        try await client.value(GitHubRequest(.get, path(owner, name, "/pages/builds/\(id)")))
    }

    /// Builds the site from the latest commit without a push. `POST /repos/{owner}/{repo}/pages/builds`
    @discardableResult
    public func requestPagesBuild(_ owner: String, _ name: String) async throws(GitHubError) -> QueuedPagesBuild {
        try await client.value(GitHubRequest(.post, path(owner, name, "/pages/builds")))
    }

    // MARK: Deployments

    /// Deploys a workflow artifact to the site. Call it from a GitHub Actions job with `pages: write` and `id-token: write`.
    /// `POST /repos/{owner}/{repo}/pages/deployments`
    @discardableResult
    public func createPagesDeployment(
        _ deployment: NewPagesDeployment, in owner: String, _ name: String
    ) async throws(GitHubError) -> PagesDeployment {
        try await client.value(GitHubRequest(.post, path(owner, name, "/pages/deployments"), body: deployment))
    }

    /// A Pages deployment's progress. `GET /repos/{owner}/{repo}/pages/deployments/{pages_deployment_id}`
    public func pagesDeploymentState(id: String, in owner: String, _ name: String) async throws(GitHubError) -> PagesDeploymentState {
        struct Response: Decodable, Sendable { let status: PagesDeploymentState }
        return try await client.value(GitHubRequest<Response>(.get, path(owner, name, "/pages/deployments/\(escape(id))"))).status
    }

    /// Cancels a Pages deployment. `POST /repos/{owner}/{repo}/pages/deployments/{pages_deployment_id}/cancel`
    public func cancelPagesDeployment(id: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(owner, name, "/pages/deployments/\(escape(id))/cancel")))
    }
}
