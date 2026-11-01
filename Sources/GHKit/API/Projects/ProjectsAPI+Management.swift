import Foundation

// Project management that only GraphQL offers: create, edit, close, delete, copy,
// templates, links, collaborators, status updates, and item archiving and ordering.
//
// These methods take the same project numbers as the REST methods and look up
// node IDs for you. Methods that change a project return it re-read over REST,
// so you always get the same `Project` type back.

extension ProjectsAPI {
    // MARK: Lifecycle

    /// Creates a project owned by this API's owner.
    ///
    /// - Parameters:
    ///   - repositoryNodeID: Links the new project to a repository.
    ///   - teamNodeID: Links the new project to a team.
    public func create(
        title: String,
        repositoryNodeID: String? = nil,
        teamNodeID: String? = nil
    ) async throws(GitHubError) -> Project {
        struct Input: Encodable, Sendable { let ownerId: String; let title: String; let repositoryId: String?; let teamId: String? }
        let ownerID = try await ownerNodeID(owner)
        let result: ProjectPayload = try await mutate(
            "createProjectV2", input: "CreateProjectV2Input",
            Input(ownerId: ownerID, title: title, repositoryId: repositoryNodeID, teamId: teamNodeID),
            select: "projectV2 { number }"
        )
        return try await project(result.number)
    }

    /// Changes a project's settings. `nil` leaves a setting as it is.
    @discardableResult
    public func update(
        _ number: Int,
        title: String? = nil,
        shortDescription: String? = nil,
        readme: String? = nil,
        isPublic: Bool? = nil
    ) async throws(GitHubError) -> Project {
        try await updateProject(number, UpdateInput(title: title, shortDescription: shortDescription, readme: readme, public: isPublic))
    }

    /// Closes a project. Closed projects are read-only until reopened.
    @discardableResult
    public func close(_ number: Int) async throws(GitHubError) -> Project {
        try await updateProject(number, UpdateInput(closed: true))
    }

    /// Reopens a closed project.
    @discardableResult
    public func reopen(_ number: Int) async throws(GitHubError) -> Project {
        try await updateProject(number, UpdateInput(closed: false))
    }

    /// Deletes a project permanently.
    public func delete(_ number: Int) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let projectId: String }
        let id = try await projectNodeID(number)
        let _: ProjectPayload = try await mutate(
            "deleteProjectV2", input: "DeleteProjectV2Input", Input(projectId: id), select: "projectV2 { number }"
        )
    }

    /// Copies a project's fields, views, and workflows (and optionally its draft issues).
    ///
    /// - Parameter destination: Who owns the copy. Defaults to this API's owner.
    public func copy(
        _ number: Int,
        title: String,
        to destination: ProjectOwner? = nil,
        includeDraftIssues: Bool = false
    ) async throws(GitHubError) -> Project {
        struct Input: Encodable, Sendable { let projectId: String; let ownerId: String; let title: String; let includeDraftIssues: Bool }
        let target = destination ?? owner
        let id = try await projectNodeID(number)
        let ownerID = try await ownerNodeID(target)
        let result: ProjectPayload = try await mutate(
            "copyProjectV2", input: "CopyProjectV2Input",
            Input(projectId: id, ownerId: ownerID, title: title, includeDraftIssues: includeDraftIssues),
            select: "projectV2 { number }"
        )
        return try await client.projects(target).project(result.number)
    }

    /// Makes an organization project available as a template.
    @discardableResult
    public func markAsTemplate(_ number: Int) async throws(GitHubError) -> Project {
        try await projectMutation("markProjectV2AsTemplate", input: "MarkProjectV2AsTemplateInput", number)
        return try await project(number)
    }

    /// Stops offering a project as a template.
    @discardableResult
    public func unmarkAsTemplate(_ number: Int) async throws(GitHubError) -> Project {
        try await projectMutation("unmarkProjectV2AsTemplate", input: "UnmarkProjectV2AsTemplateInput", number)
        return try await project(number)
    }

    // MARK: Links and access

    /// Shows the project on a repository's Projects tab.
    public func link(_ number: Int, toRepository repositoryNodeID: String) async throws(GitHubError) {
        try await linkMutation("linkProjectV2ToRepository", input: "LinkProjectV2ToRepositoryInput", number, repositoryId: repositoryNodeID)
    }

    public func unlink(_ number: Int, fromRepository repositoryNodeID: String) async throws(GitHubError) {
        try await linkMutation("unlinkProjectV2FromRepository", input: "UnlinkProjectV2FromRepositoryInput", number, repositoryId: repositoryNodeID)
    }

    /// Shows the project on a team's Projects tab.
    public func link(_ number: Int, toTeam teamNodeID: String) async throws(GitHubError) {
        try await linkMutation("linkProjectV2ToTeam", input: "LinkProjectV2ToTeamInput", number, teamId: teamNodeID)
    }

    public func unlink(_ number: Int, fromTeam teamNodeID: String) async throws(GitHubError) {
        try await linkMutation("unlinkProjectV2FromTeam", input: "UnlinkProjectV2FromTeamInput", number, teamId: teamNodeID)
    }

    /// Grants, changes, or removes (`.none`) collaborator access.
    public func updateCollaborators(of number: Int, _ collaborators: [ProjectCollaborator]) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let projectId: String; let collaborators: [ProjectCollaborator] }
        let id = try await projectNodeID(number)
        let _: Ignored = try await mutate(
            "updateProjectV2Collaborators", input: "UpdateProjectV2CollaboratorsInput",
            Input(projectId: id, collaborators: collaborators), select: "clientMutationId"
        )
    }

    // MARK: Status updates

    /// Recent status updates, newest first.
    public func statusUpdates(of number: Int, limit: Int = 20) async throws(GitHubError) -> [ProjectStatusUpdate] {
        struct Variables: Encodable, Sendable { let id: String; let first: Int }
        struct Response: Decodable, Sendable {
            struct Node: Decodable, Sendable { let statusUpdates: Connection<StatusUpdateNode>? }
            let node: Node?
        }
        let id = try await projectNodeID(number)
        let response: Response = try await client.graphQL(
            """
            query($id: ID!, $first: Int!) {
              node(id: $id) {
                ... on ProjectV2 {
                  statusUpdates(first: $first, orderBy: {field: CREATED_AT, direction: DESC}) {
                    nodes { \(StatusUpdateNode.selection) }
                  }
                }
              }
            }
            """,
            variables: Variables(id: id, first: min(max(limit, 1), 100))
        )
        return (response.node?.statusUpdates?.nodes ?? []).map { $0.model(projectNodeID: id) }
    }

    /// Posts a status update.
    public func createStatusUpdate(
        in number: Int,
        status: ProjectStatus? = nil,
        body: String? = nil,
        startDate: CalendarDate? = nil,
        targetDate: CalendarDate? = nil
    ) async throws(GitHubError) -> ProjectStatusUpdate {
        struct Input: Encodable, Sendable {
            let projectId: String; let status: ProjectStatus?; let body: String?
            let startDate: CalendarDate?; let targetDate: CalendarDate?
        }
        let id = try await projectNodeID(number)
        let result: StatusUpdatePayload = try await mutate(
            "createProjectV2StatusUpdate", input: "CreateProjectV2StatusUpdateInput",
            Input(projectId: id, status: status, body: body, startDate: startDate, targetDate: targetDate),
            select: "statusUpdate { \(StatusUpdateNode.selection) }"
        )
        return result.statusUpdate.model(projectNodeID: id)
    }

    /// Edits a status update. `nil` leaves a value as it is.
    public func updateStatusUpdate(
        _ statusUpdateNodeID: String,
        status: ProjectStatus? = nil,
        body: String? = nil,
        startDate: CalendarDate? = nil,
        targetDate: CalendarDate? = nil
    ) async throws(GitHubError) -> ProjectStatusUpdate {
        struct Input: Encodable, Sendable {
            let statusUpdateId: String; let status: ProjectStatus?; let body: String?
            let startDate: CalendarDate?; let targetDate: CalendarDate?
        }
        let result: StatusUpdatePayload = try await mutate(
            "updateProjectV2StatusUpdate", input: "UpdateProjectV2StatusUpdateInput",
            Input(statusUpdateId: statusUpdateNodeID, status: status, body: body, startDate: startDate, targetDate: targetDate),
            select: "statusUpdate { \(StatusUpdateNode.selection) }"
        )
        return result.statusUpdate.model(projectNodeID: nil)
    }

    public func deleteStatusUpdate(_ statusUpdateNodeID: String) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let statusUpdateId: String }
        let _: Ignored = try await mutate(
            "deleteProjectV2StatusUpdate", input: "DeleteProjectV2StatusUpdateInput",
            Input(statusUpdateId: statusUpdateNodeID), select: "deletedStatusUpdateId"
        )
    }

    // MARK: Items

    /// Archives an item. Archived items are hidden from views but keep their field values.
    public func archive(_ item: ProjectItem, in number: Int) async throws(GitHubError) {
        try await itemMutation("archiveProjectV2Item", input: "ArchiveProjectV2ItemInput", item, number)
    }

    public func unarchive(_ item: ProjectItem, in number: Int) async throws(GitHubError) {
        try await itemMutation("unarchiveProjectV2Item", input: "UnarchiveProjectV2ItemInput", item, number)
    }

    /// Moves an item to just after `previous`, or to the top when `previous` is `nil`.
    public func move(_ item: ProjectItem, after previous: ProjectItem?, in number: Int) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let projectId: String; let itemId: String; let afterId: String? }
        let id = try await projectNodeID(number)
        let itemID = try nodeID(of: item)
        let afterID = try previous.map { item throws(GitHubError) in try nodeID(of: item) }
        let _: Ignored = try await mutate(
            "updateProjectV2ItemPosition", input: "UpdateProjectV2ItemPositionInput",
            Input(projectId: id, itemId: itemID, afterId: afterID), select: "clientMutationId"
        )
    }

    /// Turns a draft issue item into a real issue in a repository.
    ///
    /// - Returns: The item, re-read over REST, now pointing at the new issue.
    public func convertDraftToIssue(
        _ item: ProjectItem,
        in number: Int,
        repositoryNodeID: String
    ) async throws(GitHubError) -> ProjectItem {
        struct Input: Encodable, Sendable { let itemId: String; let repositoryId: String }
        struct Payload: Decodable, Sendable { struct Item: Decodable, Sendable { let id: String }; let item: Item? }
        let _: Payload = try await mutate(
            "convertProjectV2DraftIssueItemToIssue", input: "ConvertProjectV2DraftIssueItemToIssueInput",
            Input(itemId: try nodeID(of: item), repositoryId: repositoryNodeID), select: "item { id }"
        )
        return try await self.item(item.id, of: number)
    }

    /// Edits a draft issue. Use the draft's node ID, from `item.content?.nodeID`.
    public func updateDraftIssue(
        _ draftIssueNodeID: String,
        title: String? = nil,
        body: String? = nil,
        assigneeNodeIDs: [String]? = nil
    ) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let draftIssueId: String; let title: String?; let body: String?; let assigneeIds: [String]? }
        let _: Ignored = try await mutate(
            "updateProjectV2DraftIssue", input: "UpdateProjectV2DraftIssueInput",
            Input(draftIssueId: draftIssueNodeID, title: title, body: body, assigneeIds: assigneeNodeIDs),
            select: "draftIssue { id }"
        )
    }

    // MARK: Fields

    /// Renames a field or replaces its options or iterations.
    ///
    /// Replacing single-select options keeps values only for options whose names match.
    public func updateField(
        _ field: ProjectField,
        name: String? = nil,
        options: [NewSingleSelectOption]? = nil,
        iterations: NewIterationConfiguration? = nil
    ) async throws(GitHubError) {
        struct Option: Encodable, Sendable { let name: String; let color: ProjectColor; let description: String }
        struct Iteration: Encodable, Sendable { let title: String; let startDate: CalendarDate; let duration: Int }
        struct Configuration: Encodable, Sendable { let startDate: CalendarDate; let duration: Int; let iterations: [Iteration] }
        struct Input: Encodable, Sendable {
            let fieldId: String; let name: String?
            let singleSelectOptions: [Option]?; let iterationConfiguration: Configuration?
        }
        guard let fieldID = field.nodeID else { throw .invalidRequest("Field \(field.id) has no node ID.") }
        let input = Input(
            fieldId: fieldID,
            name: name,
            singleSelectOptions: options?.map { Option(name: $0.name, color: $0.color, description: $0.description) },
            iterationConfiguration: iterations.map { config in
                Configuration(
                    startDate: config.startDate,
                    duration: config.duration,
                    iterations: config.iterations.map { Iteration(title: $0.title, startDate: $0.startDate, duration: $0.duration) }
                )
            }
        )
        let _: Ignored = try await mutate("updateProjectV2Field", input: "UpdateProjectV2FieldInput", input, select: "clientMutationId")
    }

    /// Deletes a custom field and its values.
    public func deleteField(_ field: ProjectField) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let fieldId: String }
        guard let fieldID = field.nodeID else { throw .invalidRequest("Field \(field.id) has no node ID.") }
        let _: Ignored = try await mutate(
            "deleteProjectV2Field", input: "DeleteProjectV2FieldInput", Input(fieldId: fieldID), select: "clientMutationId"
        )
    }
}

// MARK: - Plumbing

extension ProjectsAPI {
    struct UpdateInput: Encodable, Sendable {
        var projectId = ""
        var title: String?
        var shortDescription: String?
        var readme: String?
        var `public`: Bool?
        var closed: Bool?
    }

    private func updateProject(_ number: Int, _ input: UpdateInput) async throws(GitHubError) -> Project {
        var input = input
        input.projectId = try await projectNodeID(number)
        let _: ProjectPayload = try await mutate("updateProjectV2", input: "UpdateProjectV2Input", input, select: "projectV2 { number }")
        return try await project(number)
    }

    private func projectMutation(_ name: String, input: String, _ number: Int) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let projectId: String }
        let _: Ignored = try await mutate(name, input: input, Input(projectId: try await projectNodeID(number)), select: "clientMutationId")
    }

    private func linkMutation(
        _ name: String, input: String, _ number: Int,
        repositoryId: String? = nil, teamId: String? = nil
    ) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let projectId: String; let repositoryId: String?; let teamId: String? }
        let id = try await projectNodeID(number)
        let _: Ignored = try await mutate(name, input: input, Input(projectId: id, repositoryId: repositoryId, teamId: teamId), select: "clientMutationId")
    }

    private func itemMutation(_ name: String, input: String, _ item: ProjectItem, _ number: Int) async throws(GitHubError) {
        struct Input: Encodable, Sendable { let projectId: String; let itemId: String }
        let id = try await projectNodeID(number)
        let _: Ignored = try await mutate(name, input: input, Input(projectId: id, itemId: try nodeID(of: item)), select: "item { id }")
    }

    /// Runs `mutation($input: InputType!) { name(input: $input) { select } }` and decodes the payload.
    func mutate<Input: Encodable & Sendable, Payload: Decodable & Sendable>(
        _ name: String,
        input inputType: String,
        _ input: Input,
        select selection: String
    ) async throws(GitHubError) -> Payload {
        let response: MutationResponse<Payload> = try await client.graphQL(
            "mutation($input: \(inputType)!) { result: \(name)(input: $input) { \(selection) } }",
            variables: MutationVariables(input: input)
        )
        guard let payload = response.result else { throw .graphQL([]) }
        return payload
    }

    func projectNodeID(_ number: Int) async throws(GitHubError) -> String {
        try await project(number).nodeID
    }

    func ownerNodeID(_ owner: ProjectOwner) async throws(GitHubError) -> String {
        try await client.users.user(owner.login).nodeID
    }

    private func nodeID(of item: ProjectItem) throws(GitHubError) -> String {
        guard let id = item.nodeID else { throw .invalidRequest("Item \(item.id) has no node ID.") }
        return id
    }
}

private struct MutationResponse<Payload: Decodable & Sendable>: Decodable, Sendable {
    let result: Payload?
}

private struct Ignored: Decodable, Sendable {}

private struct ProjectPayload: Decodable, Sendable {
    struct Node: Decodable, Sendable { let number: Int }
    let projectV2: Node?
    var number: Int { projectV2?.number ?? 0 }
}

private struct StatusUpdatePayload: Decodable, Sendable {
    let statusUpdate: StatusUpdateNode
}

private struct Connection<Node: Decodable & Sendable>: Decodable, Sendable {
    let nodes: [Node]?
}

private struct StatusUpdateNode: Decodable, Sendable {
    static let selection = "id fullDatabaseId body status startDate targetDate createdAt updatedAt"

    let id: String
    let fullDatabaseId: String?
    let body: String?
    let status: ProjectStatus?
    let startDate: CalendarDate?
    let targetDate: CalendarDate?
    let createdAt: Date
    let updatedAt: Date

    func model(projectNodeID: String?) -> ProjectStatusUpdate {
        ProjectStatusUpdate(
            databaseID: fullDatabaseId.flatMap(Int.init),
            nodeID: id,
            projectNodeID: projectNodeID,
            status: status,
            startDate: startDate,
            targetDate: targetDate,
            body: body,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct MutationVariables<Input: Encodable & Sendable>: Encodable, Sendable {
    let input: Input
}
