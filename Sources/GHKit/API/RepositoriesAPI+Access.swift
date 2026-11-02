import Foundation

// Collaborators, invitations, deploy keys, and autolinks.
extension RepositoriesAPI {
    // MARK: Collaborators

    /// People with access to a repository. `GET /repos/{owner}/{repo}/collaborators`
    /// - Parameter role: Only people with exactly this role.
    public func collaborators(
        _ owner: String, _ name: String, affiliation: CollaboratorAffiliation = .all, role: RepositoryRole? = nil,
        perPage: Int = 100
    ) -> Paginated<Collaborator> {
        client.paginate(
            GitHubRequest(
                .get, path(owner, name, "/collaborators"),
                query: .query(("affiliation", affiliation), ("permission", role), ("per_page", perPage))))
    }

    /// Whether `login` can access a repository. `GET /repos/{owner}/{repo}/collaborators/{username}`
    public func isCollaborator(_ login: String, on owner: String, _ name: String) async throws(GitHubError) -> Bool {
        try await client.exists(path(owner, name, "/collaborators/\(escape(login))"))
    }

    /// Someone's effective access to a repository. `GET /repos/{owner}/{repo}/collaborators/{username}/permission`
    public func permission(of login: String, on owner: String, _ name: String) async throws(GitHubError) -> CollaboratorPermission {
        try await client.value(GitHubRequest(.get, path(owner, name, "/collaborators/\(escape(login))/permission")))
    }

    /// Invites someone to collaborate, or changes an existing collaborator's role.
    /// `PUT /repos/{owner}/{repo}/collaborators/{username}`
    /// - Returns: The new invitation, or `nil` when no invitation was needed, such as for organization members.
    @discardableResult
    public func addCollaborator(
        _ login: String, to owner: String, _ name: String, role: RepositoryRole = .push
    ) async throws(GitHubError) -> RepositoryInvitation? {
        struct Body: Encodable, Sendable { let permission: RepositoryRole }
        let body = Body(permission: role)
        return try await client.value(
            GitHubRequest(
                method: .put, target: .path(path(owner, name, "/collaborators/\(escape(login))")), body: .json(body)
            ) { data in
                data.isEmpty ? nil : try GitHubJSON.decoder().decode(RepositoryInvitation.self, from: data)
            })
    }

    /// Removes a collaborator, or cancels their pending invitation. `DELETE /repos/{owner}/{repo}/collaborators/{username}`
    public func removeCollaborator(_ login: String, from owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/collaborators/\(escape(login))")))
    }

    // MARK: Invitations

    /// Pending invitations to a repository. `GET /repos/{owner}/{repo}/invitations`
    public func invitations(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<RepositoryInvitation> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/invitations"), query: .query(("per_page", perPage))))
    }

    /// Changes the access a pending invitation grants. `PATCH /repos/{owner}/{repo}/invitations/{invitation_id}`
    @discardableResult
    public func updateInvitation(
        id: Int, on owner: String, _ name: String, permission: RepositoryInvitationPermission
    ) async throws(GitHubError) -> RepositoryInvitation {
        struct Body: Encodable, Sendable { let permissions: RepositoryInvitationPermission }
        return try await client.value(
            GitHubRequest(.patch, path(owner, name, "/invitations/\(id)"), body: Body(permissions: permission)))
    }

    /// Cancels a pending invitation. `DELETE /repos/{owner}/{repo}/invitations/{invitation_id}`
    public func cancelInvitation(id: Int, on owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/invitations/\(id)")))
    }

    /// Repository invitations waiting for the signed-in user. `GET /user/repository_invitations`
    public func myInvitations(perPage: Int = 100) -> Paginated<RepositoryInvitation> {
        client.paginate(GitHubRequest(.get, "/user/repository_invitations", query: .query(("per_page", perPage))))
    }

    /// Accepts a repository invitation. `PATCH /user/repository_invitations/{invitation_id}`
    public func acceptInvitation(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.patch, "/user/repository_invitations/\(id)"))
    }

    /// Declines a repository invitation. `DELETE /user/repository_invitations/{invitation_id}`
    public func declineInvitation(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/repository_invitations/\(id)"))
    }

    // MARK: Deploy keys

    /// A repository's deploy keys. `GET /repos/{owner}/{repo}/keys`
    public func deployKeys(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<DeployKey> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/keys"), query: .query(("per_page", perPage))))
    }

    /// One deploy key. `GET /repos/{owner}/{repo}/keys/{key_id}`
    public func deployKey(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> DeployKey {
        try await client.value(GitHubRequest(.get, path(owner, name, "/keys/\(id)")))
    }

    /// Adds a deploy key. Keys are read-only unless you say otherwise. `POST /repos/{owner}/{repo}/keys`
    @discardableResult
    public func addDeployKey(
        _ key: String, title: String? = nil, readOnly: Bool = true, to owner: String, _ name: String
    ) async throws(GitHubError) -> DeployKey {
        struct Body: Encodable, Sendable {
            let key: String
            let title: String?
            let readOnly: Bool
            enum CodingKeys: String, CodingKey {
                case key, title
                case readOnly = "read_only"
            }
        }
        return try await client.value(
            GitHubRequest(.post, path(owner, name, "/keys"), body: Body(key: key, title: title, readOnly: readOnly)))
    }

    /// Removes a deploy key. To change a key, delete it and add a new one. `DELETE /repos/{owner}/{repo}/keys/{key_id}`
    public func deleteDeployKey(id: Int, from owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/keys/\(id)")))
    }

    // MARK: Autolinks

    /// A repository's autolink references. `GET /repos/{owner}/{repo}/autolinks`
    public func autolinks(_ owner: String, _ name: String) async throws(GitHubError) -> [Autolink] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/autolinks")))
    }

    /// One autolink reference. `GET /repos/{owner}/{repo}/autolinks/{autolink_id}`
    public func autolink(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> Autolink {
        try await client.value(GitHubRequest(.get, path(owner, name, "/autolinks/\(id)")))
    }

    /// Links references like `JIRA-123` to another site. `POST /repos/{owner}/{repo}/autolinks`
    /// - Parameters:
    ///   - prefix: Such as `JIRA-`.
    ///   - urlTemplate: Must contain `<num>`.
    ///   - alphanumeric: Lets references contain letters as well as digits.
    @discardableResult
    public func createAutolink(
        prefix: String, urlTemplate: String, alphanumeric: Bool = true, in owner: String, _ name: String
    ) async throws(GitHubError) -> Autolink {
        struct Body: Encodable, Sendable {
            let keyPrefix: String
            let urlTemplate: String
            let isAlphanumeric: Bool
            enum CodingKeys: String, CodingKey {
                case keyPrefix = "key_prefix"
                case urlTemplate = "url_template"
                case isAlphanumeric = "is_alphanumeric"
            }
        }
        return try await client.value(
            GitHubRequest(
                .post, path(owner, name, "/autolinks"),
                body: Body(keyPrefix: prefix, urlTemplate: urlTemplate, isAlphanumeric: alphanumeric)))
    }

    /// Deletes an autolink reference. `DELETE /repos/{owner}/{repo}/autolinks/{autolink_id}`
    public func deleteAutolink(id: Int, from owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/autolinks/\(id)")))
    }
}
