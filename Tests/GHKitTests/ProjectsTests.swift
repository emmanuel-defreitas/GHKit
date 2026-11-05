import Foundation
import Testing

@testable import GHKitActivity
@testable import GHKitApps
@testable import GHKitCore
@testable import GHKitGists
@testable import GHKitIssues
@testable import GHKitOrganizations
@testable import GHKitProjects
@testable import GHKitPullRequests
@testable import GHKitRepositories
@testable import GHKitSearch
@testable import GHKitUsers

@Suite("Projects: models")
struct ProjectModelTests {
    let decoder = GitHubJSON.decoder()

    @Test func projectDecodes() throws {
        let project = try decoder.decode(Project.self, from: loadFixture("projects-v2"))
        #expect(project.number == 2)
        #expect(project.title == "My Projects")
        #expect(project.isPublic)
        #expect(project.state == .open)
        #expect(project.projectOwner == .user("octocat"))
        #expect(project.latestStatusUpdate?.status == .complete)
        #expect(project.latestStatusUpdate?.startDate == CalendarDate(year: 2025, month: 7, day: 23))
        #expect(project.webURL().absoluteString == "https://github.com/users/octocat/projects/2")
    }

    @Test func singleSelectFieldDecodes() throws {
        let field = try decoder.decode(ProjectField.self, from: loadFixture("projects-v2-field-single-select"))
        #expect(field.dataType == .singleSelect)
        #expect(field.options?.count == 3)
        #expect(field.option(named: "high")?.id == "option_3")
        #expect(field.option(named: "High")?.color == .red)
    }

    @Test func iterationFieldDecodes() throws {
        let field = try decoder.decode(ProjectField.self, from: loadFixture("projects-v2-field-iteration"))
        #expect(field.dataType == .iteration)
        #expect(field.configuration?.duration == 14)
        let sprint = try #require(field.iteration(containing: CalendarDate(year: 2022, month: 7, day: 14)))
        #expect(sprint.title.raw == "Sprint 1")
        #expect(sprint.endDate == CalendarDate(year: 2022, month: 7, day: 15))
        #expect(field.iteration(containing: CalendarDate(year: 2022, month: 7, day: 15))?.id == "iter_2")
    }

    @Test func textFieldDecodes() throws {
        let field = try decoder.decode(ProjectField.self, from: loadFixture("projects-v2-field-text"))
        #expect(field.dataType == .text)
        #expect(field.name == "Team notes")
    }

    @Test func itemWithContentDecodes() throws {
        let item = try decoder.decode(ProjectItem.self, from: loadFixture("projects-v2-item-with-content"))
        #expect(item.contentType == .pullRequest)
        #expect(item.content?.number == 6)
        #expect(item.fields?.count == 11)
        #expect(item.value(forFieldNamed: "Status")?.singleSelectOptionName == "Done")
        #expect(item.value(forFieldNamed: "status")?.singleSelectOptionID == "98236657")
        #expect(item.value(forField: 1)?.text?.isEmpty == false)
        #expect(item.value(forField: 2)?.value?.arrayValue?.first?["login"]?.stringValue == "octocat")
        #expect(item.isArchived == false)
    }

    @Test func draftItemDecodes() throws {
        let item = try decoder.decode(ProjectItem.self, from: loadFixture("projects-v2-item-simple"))
        #expect(item.contentType == .draftIssue)
        #expect(item.title == "Example Draft Issue")
        #expect(item.content?.nodeID != nil)
    }

    @Test func viewDecodes() throws {
        let view = try decoder.decode(ProjectView.self, from: loadFixture("projects-v2-view"))
        #expect(view.layout == .board)
        #expect(view.sortBy == [ProjectViewSort(fieldID: 123, direction: .ascending), ProjectViewSort(fieldID: 456, direction: .descending)])
        #expect(view.verticalGroupBy == [456])
    }

    @Test func unknownEnumValuesSurvive() throws {
        let type = try JSONDecoder().decode(ProjectFieldDataType.self, from: Data(#""brand_new_type""#.utf8))
        #expect(type.rawValue == "brand_new_type")
    }
}

@Suite("Projects: REST requests")
struct ProjectRequestTests {
    let project = String(decoding: loadFixture("projects-v2"), as: UTF8.self)
    let item = String(decoding: loadFixture("projects-v2-item-simple"), as: UTF8.self)

    @Test(arguments: [
        (ProjectOwner.organization("acme"), "/orgs/acme/projectsV2/2"),
        (ProjectOwner.user("octocat"), "/users/octocat/projectsV2/2"),
    ])
    func projectPathsByOwner(owner: ProjectOwner, path: String) async throws {
        let transport = MockTransport(.json(project))
        _ = try await makeClient(transport).projects(owner).project(2)
        #expect(transport.requests.first?.path == path)
    }

    @Test func itemsRequestIncludesFilterAndFields() async throws {
        let transport = MockTransport(.json("[]"))
        _ = try await makeClient(transport).projects(.organization("acme"))
            .items(of: 5, matching: "is:open", fields: [1, 2, 3], perPage: 100).collect()
        let request = try #require(transport.requests.first)
        #expect(request.path == "/orgs/acme/projectsV2/5/items")
        #expect(request.queryItems == ["q": "is:open", "fields": "1,2,3", "per_page": "100"])
    }

    @Test func addItemByRepositoryAndNumber() async throws {
        let transport = MockTransport(.json(item, status: 201))
        _ = try await makeClient(transport).projects(.organization("acme"))
            .addItem(.issue(owner: "acme", repository: "app", number: 12), to: 5)
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.jsonBody == ["type": "Issue", "owner": "acme", "repo": "app", "number": 12])
    }

    @Test func addItemByID() async throws {
        let transport = MockTransport(.json(item, status: 201))
        _ = try await makeClient(transport).projects(.organization("acme")).addItem(.pullRequest(id: 99), to: 5)
        #expect(transport.requests.first?.jsonBody == ["type": "PullRequest", "id": 99])
    }

    @Test func updateItemEncodesEveryValueKind() async throws {
        let transport = MockTransport(.json(item))
        _ = try await makeClient(transport).projects(.organization("acme")).updateItem(
            17, in: 5,
            [
                ProjectFieldUpdate(fieldID: 1, value: .text("Hello")),
                ProjectFieldUpdate(fieldID: 2, value: .number(3.5)),
                ProjectFieldUpdate(fieldID: 3, value: .date(CalendarDate(year: 2026, month: 1, day: 9))),
                ProjectFieldUpdate(fieldID: 4, value: .singleSelect(optionID: "opt")),
                ProjectFieldUpdate(fieldID: 5, value: .clear),
            ])
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "PATCH")
        #expect(request.path == "/orgs/acme/projectsV2/5/items/17")
        #expect(
            request.jsonBody == [
                "fields": [
                    ["id": 1, "value": "Hello"],
                    ["id": 2, "value": 3.5],
                    ["id": 3, "value": "2026-01-09"],
                    ["id": 4, "value": "opt"],
                    ["id": 5, "value": nil],
                ]
            ])
    }

    @Test func addSingleSelectField() async throws {
        let transport = MockTransport(.fixture("projects-v2-field-single-select", status: 201))
        _ = try await makeClient(transport).projects(.organization("acme")).addField(
            .singleSelect(name: "Priority", options: [NewSingleSelectOption("High", color: .red)]), to: 5
        )
        #expect(
            transport.requests.first?.jsonBody == [
                "name": "Priority", "data_type": "single_select",
                "single_select_options": [["name": "High", "color": "RED", "description": ""]],
            ])
    }

    @Test func addIterationField() async throws {
        let transport = MockTransport(.fixture("projects-v2-field-iteration", status: 201))
        let start = CalendarDate(year: 2026, month: 1, day: 5)
        _ = try await makeClient(transport).projects(.organization("acme")).addField(
            .iteration(
                name: "Sprint",
                configuration: NewIterationConfiguration(startDate: start, duration: 7, iterations: [NewIteration(title: "S1", startDate: start, duration: 7)])),
            to: 5
        )
        #expect(
            transport.requests.first?.jsonBody == [
                "name": "Sprint", "data_type": "iteration",
                "iteration_configuration": [
                    "start_date": "2026-01-05", "duration": 7,
                    "iterations": [["title": "S1", "start_date": "2026-01-05", "duration": 7]],
                ],
            ])
    }

    @Test func createBoardView() async throws {
        let transport = MockTransport(.fixture("projects-v2-view", status: 201))
        let view = try await makeClient(transport).projects(.organization("acme")).createView(
            NewProjectView(name: "Board", layout: .board, filter: "is:open", sortBy: [ProjectViewSort(fieldID: 1, direction: .descending)], columnField: 3),
            in: 5
        )
        #expect(view.name == "Sprint Board")
        #expect(transport.requests.first?.path == "/orgs/acme/projectsV2/5/views")
        #expect(
            transport.requests.first?.jsonBody == [
                "name": "Board", "layout": "board", "filter": "is:open",
                "sort_by": [[1, "desc"]], "vertical_group_by": [3],
            ])
    }

    @Test func userDraftsUseNumericUserID() async throws {
        let transport = MockTransport { request, _ in
            request.path == "/users/octocat" ? .fixture("private-user") : .json(item, status: 201)
        }
        let draft = try await makeClient(transport).projects(.user("octocat")).addDraftIssue(title: "Idea", body: "Details", to: 3)
        #expect(draft.contentType == .draftIssue)
        #expect(transport.requests.map(\.path) == ["/users/octocat", "/user/1/projectsV2/3/drafts"])
        #expect(transport.requests[1].jsonBody == ["title": "Idea", "body": "Details"])
    }

    @Test func orgDraftsUseOrgPath() async throws {
        let transport = MockTransport(.json(item, status: 201))
        _ = try await makeClient(transport).projects(.organization("acme")).addDraftIssue(title: "Idea", to: 3)
        #expect(transport.requests.map(\.path) == ["/orgs/acme/projectsV2/3/drafts"])
        #expect(transport.requests[0].jsonBody == ["title": "Idea"])
    }

    @Test func deleteItem() async throws {
        let transport = MockTransport(.noContent())
        try await makeClient(transport).projects(.organization("acme")).deleteItem(17, from: 5)
        #expect(transport.requests.first?.httpMethod == "DELETE")
        #expect(transport.requests.first?.path == "/orgs/acme/projectsV2/5/items/17")
    }

    @Test func fieldNamedSearchesAllPages() async throws {
        let text = String(decoding: loadFixture("projects-v2-field-text"), as: UTF8.self)
        let select = String(decoding: loadFixture("projects-v2-field-single-select"), as: UTF8.self)
        let transport = MockTransport(
            .json("[\(text)]", headers: ["Link": #"<https://api.github.com/orgs/acme/projectsV2/5/fields?after=x>; rel="next""#]),
            .json("[\(select)]")
        )
        let field = try await makeClient(transport).projects(.organization("acme")).field(named: "priority", of: 5)
        #expect(field.id == 12345)
    }
}

@Suite("Projects: GraphQL management")
struct ProjectManagementTests {
    let project = String(decoding: loadFixture("projects-v2"), as: UTF8.self)
    let org = #"{"login":"acme","id":9,"node_id":"O_acme","type":"Organization"}"#

    @Test func createResolvesOwnerAndReturnsRESTProject() async throws {
        let transport = MockTransport { [project, org] request, _ in
            switch request.path {
            case "/users/acme": .json(org)
            case "/graphql": .json(#"{"data":{"result":{"projectV2":{"number":2}}}}"#)
            default: .json(project)
            }
        }
        let created = try await makeClient(transport).projects(.organization("acme")).create(title: "Roadmap", repositoryNodeID: "R_1")
        #expect(created.number == 2)
        #expect(transport.requests.map(\.path) == ["/users/acme", "/graphql", "/orgs/acme/projectsV2/2"])

        let body = try #require(transport.requests[1].jsonBody)
        #expect(body["query"]?.stringValue?.contains("createProjectV2(input: $input)") == true)
        #expect(body["variables"] == ["input": ["ownerId": "O_acme", "title": "Roadmap", "repositoryId": "R_1"]])
    }

    @Test func closeSendsClosedFlag() async throws {
        let transport = MockTransport { [project] request, _ in
            request.path == "/graphql" ? .json(#"{"data":{"result":{"projectV2":{"number":2}}}}"#) : .json(project)
        }
        _ = try await makeClient(transport).projects(.organization("acme")).close(2)
        let body = try #require(transport.requests[1].jsonBody)
        #expect(body["variables"] == ["input": ["projectId": "MDc6UHJvamVjdDEwMDI2MDM=", "closed": true]])
        #expect(body["query"]?.stringValue?.contains("UpdateProjectV2Input") == true)
    }

    @Test func statusUpdateRoundTrip() async throws {
        let transport = MockTransport { [project] request, _ in
            request.path == "/graphql"
                ? .json(
                    #"{"data":{"result":{"statusUpdate":{"id":"PVTSU_1","fullDatabaseId":"77","body":"Going well","status":"ON_TRACK","startDate":"2026-01-01","targetDate":"2026-02-01","createdAt":"2026-01-02T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z"}}}}"#
                )
                : .json(project)
        }
        let update = try await makeClient(transport).projects(.organization("acme")).createStatusUpdate(
            in: 2, status: .onTrack, body: "Going well", targetDate: CalendarDate(year: 2026, month: 2, day: 1)
        )
        #expect(update.status == .onTrack)
        #expect(update.databaseID == 77)
        #expect(update.projectNodeID == "MDc6UHJvamVjdDEwMDI2MDM=")
        let variables = try #require(transport.requests[1].jsonBody?["variables"])
        #expect(variables == ["input": ["projectId": "MDc6UHJvamVjdDEwMDI2MDM=", "status": "ON_TRACK", "body": "Going well", "targetDate": "2026-02-01"]])
    }

    @Test func archiveUsesItemNodeID() async throws {
        let item = try GitHubJSON.decoder().decode(ProjectItem.self, from: loadFixture("projects-v2-item-simple"))
        let transport = MockTransport { [project] request, _ in
            request.path == "/graphql" ? .json(#"{"data":{"result":{"item":{"id":"x"}}}}"#) : .json(project)
        }
        try await makeClient(transport).projects(.organization("acme")).archive(item, in: 2)
        let variables = try #require(transport.requests[1].jsonBody?["variables"]?["input"])
        #expect(variables["itemId"]?.stringValue == item.nodeID)
    }

    @Test func mutationErrorsSurface() async {
        let transport = MockTransport { [project] request, _ in
            request.path == "/graphql"
                ? .json(#"{"data":{"result":null},"errors":[{"type":"FORBIDDEN","message":"Resource not accessible by integration"}]}"#)
                : .json(project)
        }
        do {
            try await makeClient(transport).projects(.organization("acme")).delete(2)
            Issue.record("Expected an error")
        } catch {
            guard case .graphQL(let errors) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(errors.first?.type == "FORBIDDEN")
        }
    }
}
