import Foundation
import GHKitCore

extension GitHubClient {
    /// Projects owned by an organization or a user.
    ///
    ///     let acme = github.projects(.organization("acme"))
    ///     let roadmap = try await acme.project(1)
    public func projects(_ owner: ProjectOwner) -> ProjectsAPI {
        ProjectsAPI(client: self, owner: owner)
    }

    /// Projects owned by the same account as `project`.
    public func projects(ownerOf project: Project) -> ProjectsAPI {
        ProjectsAPI(client: self, owner: project.projectOwner)
    }
}

/// Projects (v2) for one owner.
///
/// Reading and item, field, and view changes use the REST API. Creating, editing,
/// closing, deleting, copying, and linking projects use GraphQL, because REST
/// doesn't offer them. See `ProjectsAPI+Management.swift`.
///
/// Required access: the `read:project` or `project` scope for OAuth tokens, or the
/// "Projects" organization permission (or "Projects" account permission for user
/// projects) for GitHub Apps and fine-grained tokens.
///
/// Part of the `GHKitProjects` library.
public struct ProjectsAPI: Sendable {
    let client: GitHubClient
    public let owner: ProjectOwner

    private func path(_ number: Int, _ suffix: String = "") -> String {
        "\(owner.pathPrefix)/projectsV2/\(number)\(suffix)"
    }

    // MARK: Projects

    /// The request behind ``list(matching:perPage:)``, for use with `GitHubClient.page(_:at:)`.
    public func listRequest(matching query: String? = nil, perPage: Int = 30) -> GitHubRequest<[Project]> {
        GitHubRequest(.get, "\(owner.pathPrefix)/projectsV2", query: .query(("q", query), ("per_page", perPage)))
    }

    /// Every project the owner has that you can see.
    ///
    /// `GET /orgs/{org}/projectsV2`, `GET /users/{username}/projectsV2`
    /// - Parameter query: Filters projects, for example `is:open`.
    public func list(matching query: String? = nil, perPage: Int = 30) -> Paginated<Project> {
        client.paginate(listRequest(matching: query, perPage: perPage))
    }

    /// One project by number.
    ///
    /// `GET /orgs/{org}/projectsV2/{project_number}`, `GET /users/{username}/projectsV2/{project_number}`
    public func project(_ number: Int) async throws(GitHubError) -> Project {
        try await client.value(GitHubRequest(.get, path(number)))
    }

    // MARK: Fields

    /// Every field in a project.
    ///
    /// `GET …/projectsV2/{project_number}/fields`
    public func fields(of number: Int, perPage: Int = 50) -> Paginated<ProjectField> {
        client.paginate(GitHubRequest(.get, path(number, "/fields"), query: .query(("per_page", perPage))))
    }

    /// One field.
    ///
    /// `GET …/projectsV2/{project_number}/fields/{field_id}`
    public func field(_ fieldID: Int, of number: Int) async throws(GitHubError) -> ProjectField {
        try await client.value(GitHubRequest(.get, path(number, "/fields/\(fieldID)")))
    }

    /// The field with this name, ignoring case. Throws `.invalidRequest` if there's none.
    public func field(named name: String, of number: Int) async throws(GitHubError) -> ProjectField {
        var iterator = fields(of: number, perPage: 100).makeAsyncIterator()
        while let field = try await iterator.next() {
            if field.name.caseInsensitiveCompare(name) == .orderedSame { return field }
        }
        throw .invalidRequest("Project \(number) has no field named “\(name)”.")
    }

    /// Adds a field.
    ///
    /// `POST …/projectsV2/{project_number}/fields`
    public func addField(_ field: NewProjectField, to number: Int) async throws(GitHubError) -> ProjectField {
        try await client.value(GitHubRequest(.post, path(number, "/fields"), body: field))
    }

    // MARK: Items

    /// The request behind ``items(of:matching:fields:perPage:)``, for manual paging.
    public func itemsRequest(
        of number: Int,
        matching query: String? = nil,
        fields: [Int]? = nil,
        perPage: Int = 50
    ) -> GitHubRequest<[ProjectItem]> {
        GitHubRequest(
            .get, path(number, "/items"),
            query: .query(
                ("q", query),
                ("fields", fields.map(Self.fieldList)),
                ("per_page", perPage)
            ))
    }

    /// Every item in a project.
    ///
    /// `GET …/projectsV2/{project_number}/items`
    /// - Parameters:
    ///   - query: A filter, using the same syntax as the project UI, such as `is:open label:bug`.
    ///   - fields: Field IDs whose values to include (up to 50). Without it, only Title comes back.
    public func items(
        of number: Int,
        matching query: String? = nil,
        fields: [Int]? = nil,
        perPage: Int = 50
    ) -> Paginated<ProjectItem> {
        client.paginate(itemsRequest(of: number, matching: query, fields: fields, perPage: perPage))
    }

    /// One item.
    ///
    /// `GET …/projectsV2/{project_number}/items/{item_id}`
    public func item(_ itemID: Int, of number: Int, fields: [Int]? = nil) async throws(GitHubError) -> ProjectItem {
        try await client.value(
            GitHubRequest(
                .get, path(number, "/items/\(itemID)"),
                query: .query(("fields", fields.map(Self.fieldList)))
            ))
    }

    /// Adds an existing issue or pull request.
    ///
    /// `POST …/projectsV2/{project_number}/items`
    public func addItem(_ content: ProjectItemContentReference, to number: Int) async throws(GitHubError) -> ProjectItem {
        try await client.value(GitHubRequest(.post, path(number, "/items"), body: content))
    }

    /// Creates a draft issue in the project.
    ///
    /// `POST /orgs/{org}/projectsV2/{project_number}/drafts`, `POST /user/{user_id}/projectsV2/{project_number}/drafts`
    public func addDraftIssue(title: String, body: String? = nil, to number: Int) async throws(GitHubError) -> ProjectItem {
        struct Draft: Encodable, Sendable { let title: String; let body: String? }
        let path: String =
            switch owner {
            case .organization: path(number, "/drafts")
            case .user: "/user/\(try await ownerUserID())/projectsV2/\(number)/drafts"
            }
        return try await client.value(GitHubRequest(.post, path, body: Draft(title: title, body: body)))
    }

    /// Sets field values on an item.
    ///
    /// `PATCH …/projectsV2/{project_number}/items/{item_id}`
    ///
    ///     let status = try await acme.field(named: "Status", of: 1)
    ///     try await acme.updateItem(item.id, in: 1, [
    ///         .set(status, to: .singleSelect(optionID: status.option(named: "Done")!.id)),
    ///     ])
    @discardableResult
    public func updateItem(
        _ itemID: Int,
        in number: Int,
        _ updates: [ProjectFieldUpdate]
    ) async throws(GitHubError) -> ProjectItem {
        struct Body: Encodable, Sendable { let fields: [ProjectFieldUpdate] }
        return try await client.value(GitHubRequest(.patch, path(number, "/items/\(itemID)"), body: Body(fields: updates)))
    }

    /// Sets one field value on an item.
    @discardableResult
    public func updateItem(
        _ itemID: Int,
        in number: Int,
        field fieldID: Int,
        to value: ProjectFieldValue
    ) async throws(GitHubError) -> ProjectItem {
        try await updateItem(itemID, in: number, [ProjectFieldUpdate(fieldID: fieldID, value: value)])
    }

    /// Removes an item from the project. The issue or pull request itself is untouched.
    ///
    /// `DELETE …/projectsV2/{project_number}/items/{item_id}`
    public func deleteItem(_ itemID: Int, from number: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(number, "/items/\(itemID)")))
    }

    // MARK: Views

    /// Creates a view.
    ///
    /// `POST /orgs/{org}/projectsV2/{project_number}/views`, `POST /users/{user_id}/projectsV2/{project_number}/views`
    public func createView(_ view: NewProjectView, in number: Int) async throws(GitHubError) -> ProjectView {
        let path: String =
            switch owner {
            case .organization: path(number, "/views")
            case .user: "/users/\(try await ownerUserID())/projectsV2/\(number)/views"
            }
        return try await client.value(GitHubRequest(.post, path, body: view))
    }

    /// Items as a view shows them, with its filter and sorting applied.
    ///
    /// `GET …/projectsV2/{project_number}/views/{view_number}/items`
    public func items(
        inView viewNumber: Int,
        of number: Int,
        fields: [Int]? = nil,
        perPage: Int = 50
    ) -> Paginated<ProjectItem> {
        client.paginate(
            GitHubRequest(
                .get, path(number, "/views/\(viewNumber)/items"),
                query: .query(
                    ("fields", fields.map(Self.fieldList)),
                    ("per_page", perPage)
                )))
    }

    // MARK: Helpers

    /// The user-project draft and view endpoints take a numeric user ID, not a login.
    func ownerUserID() async throws(GitHubError) -> Int {
        try await account(owner.login).id
    }

    /// Fetched directly rather than through `UsersAPI`, which lives in GHKitUsers.
    func account(_ login: String) async throws(GitHubError) -> SimpleUser {
        try await client.value(GitHubRequest(.get, "/users/\(escape(login))"))
    }

    private static func fieldList(_ ids: [Int]) -> String {
        ids.map(String.init).joined(separator: ",")
    }
}
