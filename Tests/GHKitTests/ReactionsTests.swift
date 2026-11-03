import Foundation
import Testing

@testable import GHKit

@Suite("Reactions")
struct ReactionsTests {
    let decoder = GitHubJSON.decoder()

    @Test func reactionDecodes() throws {
        let reaction = try decoder.decode(Reaction.self, from: loadFixture("reaction"))
        #expect(reaction.id == 1)
        #expect(reaction.content == .heart)
        #expect(reaction.user?.login == "octocat")
        let items = try decoder.decode([Reaction].self, from: loadFixture("reaction-items"))
        #expect(items.first?.content == .heart)
        #expect(ReactionContent.thumbsUp.rawValue == "+1")
    }

    @Test func listsEachKindOfSubject() async throws {
        let transport = MockTransport(.fixture("reaction-items"))
        let reactions = makeClient(transport).reactions
        let subjects: [ReactionSubject] = [
            .issue(1347), .issueComment(id: 1), .commitComment(id: 2), .reviewComment(id: 3), .release(id: 4),
        ]
        for subject in subjects {
            _ = try await reactions.list(on: subject, in: "octocat", "Hello-World").collect()
        }
        _ = try await reactions.list(on: .issue(1347), in: "octocat", "Hello-World", content: .thumbsUp, perPage: 10).collect()
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/issues/1347/reactions",
                "GET /repos/octocat/Hello-World/issues/comments/1/reactions",
                "GET /repos/octocat/Hello-World/comments/2/reactions",
                "GET /repos/octocat/Hello-World/pulls/comments/3/reactions",
                "GET /repos/octocat/Hello-World/releases/4/reactions",
                "GET /repos/octocat/Hello-World/issues/1347/reactions",
            ])
        #expect(transport.requests[0].queryItems == ["per_page": "100"])
        #expect(transport.requests[5].queryItems == ["content": "+1", "per_page": "10"])
    }

    @Test func addsAReaction() async throws {
        let transport = MockTransport(.fixture("reaction", status: 201))
        let reaction = try await makeClient(transport).reactions.add(.heart, to: .reviewComment(id: 3), in: "octocat", "Hello-World")
        #expect(reaction.content == .heart)
        #expect(transport.requests[0].route == "POST /repos/octocat/Hello-World/pulls/comments/3/reactions")
        #expect(transport.requests[0].jsonBody == ["content": "heart"])
    }

    @Test func deletesAReaction() async throws {
        let transport = MockTransport(.noContent())
        try await makeClient(transport).reactions.delete(id: 9, from: .release(id: 4), in: "octocat", "Hello-World")
        try await makeClient(transport).reactions.delete(id: 9, from: .issue(1347), in: "octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "DELETE /repos/octocat/Hello-World/releases/4/reactions/9",
                "DELETE /repos/octocat/Hello-World/issues/1347/reactions/9",
            ])
    }
}
