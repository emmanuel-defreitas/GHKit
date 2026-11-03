import Foundation
import Testing

@testable import GHKit

@Suite("Activity")
struct ActivityTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func eventsDecode() throws {
        let fixtures = [
            "public-events-items", "public-repo-events-items", "public-org-events-items", "repo-events-items", "user-events-items",
            "user-org-events-items", "user-public-events-items", "user-received-events-items", "user-received-public-events-items",
        ]
        for fixture in fixtures {
            let events = try decoder.decode([GitHubEvent].self, from: loadFixture(fixture))
            #expect(!events.isEmpty, "\(fixture)")
        }
        let events = try decoder.decode([GitHubEvent].self, from: loadFixture("public-events-items"))
        #expect(events[0].type == .watch)
        #expect(events[0].actor.login == "octocat")
        #expect(events[0].repository.name == "octocat/Hello-World")
        #expect(events[0].payload["action"] == "started")
        #expect(events[0].isPublic)
        #expect(events[1].type == .push)
    }

    @Test func notificationModelsDecode() throws {
        let thread = try decoder.decode(NotificationThread.self, from: loadFixture("thread"))
        #expect(thread.id == "1")
        #expect(thread.reason == .subscribed)
        #expect(thread.subject.type == .issue)
        #expect(thread.subject.title == "Greetings")
        #expect(thread.isUnread)
        #expect(thread.lastReadAt != nil)
        #expect(thread.repository.fullName == "octocat/Hello-World")
        _ = try decoder.decode([NotificationThread].self, from: loadFixture("thread-items"))

        let subscription = try decoder.decode(ThreadSubscription.self, from: loadFixture("thread-subscription"))
        #expect(subscription.isSubscribed)
        #expect(!subscription.isIgnored)

        let feeds = try decoder.decode(Feeds.self, from: loadFixture("feed"))
        #expect(feeds.timelineURL == "https://github.com/timeline")
        #expect(feeds.links.timeline?.type == "application/atom+xml")
    }

    @Test func starModelsDecode() throws {
        let stargazers = try decoder.decode(
            [Stargazer].self, from: loadFixture("stargazer-items-alternative-response-with-star-creation-timestamps"))
        #expect(stargazers.first?.user?.login == "octocat")
        let starred = try decoder.decode(
            [StarredRepository].self, from: loadFixture("starred-repository-items-alternative-response-with-star-creation-timestamps"))
        #expect(starred.first?.repository.fullName == "octocat/Hello-World")
        #expect(starred.first?.starredAt == Date(timeIntervalSince1970: 1_295_204_803))

        let history = try decoder.decode([StarHistoryWeek].self, from: loadFixture("stargazer-history-items"))
        #expect(history.first?.week == Date(timeIntervalSince1970: 1_754_784_000))
        #expect(history.first?.total == 19)
        #expect(history.first?.days == [0, 12, 7, 0, 0, 0, 0])
        let again = try decoder.decode([StarHistoryWeek].self, from: GitHubJSON.encoder().encode(history))
        #expect(again == history)

        let subscription = try decoder.decode(RepositorySubscription.self, from: loadFixture("repository-subscription"))
        #expect(subscription.isSubscribed)
        #expect(subscription.repositoryURL?.absoluteString == "https://api.github.com/repos/octocat/example")
    }

    // MARK: Events and feeds

    @Test func listsEventsFromEachSource() async throws {
        let transport = MockTransport(.fixture("public-events-items"))
        let activity = makeClient(transport).activity
        let sources: [EventSource] = [
            .everyone, .repository(owner: "octocat", name: "Hello-World"), .network(owner: "octocat", name: "Hello-World"),
            .organization("acme"), .user("mona"), .userPublic("mona"), .received("mona"), .receivedPublic("mona"),
            .dashboard(login: "mona", organization: "acme"),
        ]
        for source in sources {
            _ = try await activity.events(source).collect()
        }
        #expect(
            transport.requests.map(\.path) == [
                "/events", "/repos/octocat/Hello-World/events", "/networks/octocat/Hello-World/events", "/orgs/acme/events",
                "/users/mona/events", "/users/mona/events/public", "/users/mona/received_events",
                "/users/mona/received_events/public", "/users/mona/events/orgs/acme",
            ])
        #expect(transport.requests[0].queryItems == ["per_page": "100"])
    }

    @Test func eventsPageByNumberWithoutLinkHeaders() async throws {
        let transport = MockTransport { _, index in
            index == 0 ? .fixture("public-events-items") : .json("[]")
        }
        let events = try await makeClient(transport).activity.events(perPage: 2).collect()
        #expect(events.count == 2)
        #expect(transport.requests.map(\.queryItems) == [["per_page": "2"], ["per_page": "2", "page": "2"]])
    }

    @Test func fetchesFeeds() async throws {
        let transport = MockTransport(.fixture("feed"))
        let feeds = try await makeClient(transport).activity.feeds()
        #expect(feeds.userURL == "https://github.com/{user}")
        #expect(transport.requests.map(\.route) == ["GET /feeds"])
    }

    // MARK: Notifications

    @Test func listsNotifications() async throws {
        let transport = MockTransport(.fixture("thread-items"))
        let activity = makeClient(transport).activity
        _ = try await activity.notifications().collect()
        let since = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await activity.notifications(
            matching: NotificationFilter(includeRead: true, participatingOnly: true, since: since, before: since)
        ).collect()
        _ = try await activity.notifications(in: "octocat", "Hello-World", perPage: 10).collect()
        #expect(transport.requests[0].route == "GET /notifications")
        #expect(transport.requests[0].queryItems == ["per_page": "50"])
        #expect(
            transport.requests[1].queryItems == [
                "all": "true", "participating": "true", "since": "2023-11-14T22:13:20Z", "before": "2023-11-14T22:13:20Z",
                "per_page": "50",
            ])
        #expect(transport.requests[2].route == "GET /repos/octocat/Hello-World/notifications")
        #expect(transport.requests[2].queryItems == ["per_page": "10"])
    }

    @Test func marksNotificationsRead() async throws {
        let transport = MockTransport { _, index in
            index == 0
                ? .json(#"{"message": "Unread notifications couldn't be marked in a single request."}"#, status: 202)
                : MockResponse(status: 205)
        }
        let activity = makeClient(transport).activity
        try await activity.markNotificationsRead()
        try await activity.markNotificationsRead(before: Date(timeIntervalSince1970: 1_700_000_000))
        try await activity.markNotificationsRead(in: "octocat", "Hello-World")
        #expect(transport.requests[0].route == "PUT /notifications")
        #expect(transport.requests[0].jsonBody == ["read": true])
        #expect(transport.requests[1].jsonBody == ["read": true, "last_read_at": "2023-11-14T22:13:20Z"])
        #expect(transport.requests[2].route == "PUT /repos/octocat/Hello-World/notifications")
        #expect(transport.requests[2].jsonBody == [:])
    }

    @Test func managesThreads() async throws {
        let transport = MockTransport { request, _ in
            switch request.httpMethod {
            case "GET" where request.url!.path().hasSuffix("subscription"), "PUT": .fixture("thread-subscription")
            case "GET": .fixture("thread")
            case "PATCH": MockResponse(status: 205)
            default: .noContent()
            }
        }
        let activity = makeClient(transport).activity
        let thread = try await activity.thread(id: "1")
        #expect(thread.subject.title == "Greetings")
        try await activity.markThreadRead(id: "1")
        try await activity.markThreadDone(id: "1")
        let subscription = try await activity.threadSubscription(id: "1")
        #expect(subscription.isSubscribed)
        try await activity.subscribeToThread(id: "1")
        try await activity.subscribeToThread(id: "1", ignored: true)
        try await activity.unsubscribeFromThread(id: "1")
        #expect(
            transport.requests.map(\.route) == [
                "GET /notifications/threads/1", "PATCH /notifications/threads/1", "DELETE /notifications/threads/1",
                "GET /notifications/threads/1/subscription", "PUT /notifications/threads/1/subscription",
                "PUT /notifications/threads/1/subscription", "DELETE /notifications/threads/1/subscription",
            ])
        #expect(transport.requests[4].jsonBody == ["ignored": false])
        #expect(transport.requests[5].jsonBody == ["ignored": true])
    }

    // MARK: Stars

    @Test func listsStargazers() async throws {
        let transport = MockTransport { request, _ in
            if request.url!.path().hasSuffix("count") { return .json(#"{"count": 42}"#) }
            if request.url!.path().hasSuffix("history") { return .fixture("stargazer-history-items") }
            return request.value(forHTTPHeaderField: "Accept") == "application/vnd.github.star+json"
                ? .fixture("stargazer-items-alternative-response-with-star-creation-timestamps")
                : .fixture("simple-user-items-default-response")
        }
        let activity = makeClient(transport).activity
        let users = try await activity.stargazers(of: "octocat", "Hello-World").collect()
        #expect(users.first?.login == "octocat")
        let stars = try await activity.stars(on: "octocat", "Hello-World", perPage: 10).collect()
        #expect(stars.first?.user?.login == "octocat")
        #expect(try await activity.stargazerCount(of: "octocat", "Hello-World") == 42)
        let history = try await activity.starHistory(of: "octocat", "Hello-World").collect()
        #expect(history.first?.total == 19)
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/stargazers", "GET /repos/octocat/Hello-World/stargazers",
                "GET /repos/octocat/Hello-World/stargazers/count", "GET /repos/octocat/Hello-World/stargazers/history",
            ])
        #expect(transport.requests[1].queryItems == ["per_page": "10"])
        #expect(transport.requests[3].queryItems == ["per_page": "30"])
    }

    @Test func listsStarredRepositories() async throws {
        let transport = MockTransport { request, _ in
            request.value(forHTTPHeaderField: "Accept") == "application/vnd.github.star+json"
                ? .fixture("starred-repository-items-alternative-response-with-star-creation-timestamps")
                : .fixture("repository-items-default-response")
        }
        let activity = makeClient(transport).activity
        let repositories = try await activity.starredRepositories().collect()
        #expect(repositories.first?.fullName == "octocat/Hello-World")
        _ = try await activity.starredRepositories(by: "mona", sort: .updated, ascending: true).collect()
        let stars = try await activity.stars(by: "mona").collect()
        #expect(stars.first?.repository.fullName == "octocat/Hello-World")
        #expect(transport.requests.map(\.path) == ["/user/starred", "/users/mona/starred", "/users/mona/starred"])
        #expect(transport.requests[0].queryItems == ["sort": "created", "per_page": "100"])
        #expect(transport.requests[1].queryItems == ["sort": "updated", "direction": "asc", "per_page": "100"])
        #expect(transport.requests[2].value(forHTTPHeaderField: "Accept") == "application/vnd.github.star+json")
    }

    @Test func starsAndUnstars() async throws {
        let transport = MockTransport { _, index in index == 1 ? .json(#"{"message": "Not Found"}"#, status: 404) : .noContent() }
        let activity = makeClient(transport).activity
        #expect(try await activity.isStarred("octocat", "Hello-World"))
        #expect(try await !activity.isStarred("octocat", "Hello-World"))
        try await activity.star("octocat", "Hello-World")
        try await activity.unstar("octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "GET /user/starred/octocat/Hello-World", "GET /user/starred/octocat/Hello-World",
                "PUT /user/starred/octocat/Hello-World", "DELETE /user/starred/octocat/Hello-World",
            ])
    }

    // MARK: Watching

    @Test func listsWatchers() async throws {
        let transport = MockTransport { request, _ in
            request.url!.path().hasSuffix("subscribers") ? .fixture("simple-user-items") : .fixture("minimal-repository-items")
        }
        let activity = makeClient(transport).activity
        _ = try await activity.watchers(of: "octocat", "Hello-World").collect()
        _ = try await activity.watchedRepositories().collect()
        _ = try await activity.watchedRepositories(by: "mona").collect()
        #expect(
            transport.requests.map(\.path) == [
                "/repos/octocat/Hello-World/subscribers", "/user/subscriptions", "/users/mona/subscriptions",
            ])
    }

    @Test func watchesAndUnwatches() async throws {
        let transport = MockTransport { _, index in
            switch index {
            case 0: .fixture("repository-subscription-response-if-you-subscribe-to-the-repository")
            case 1: .json(#"{"message": "Not Found"}"#, status: 404)
            case 2, 3: .fixture("repository-subscription")
            default: .noContent()
            }
        }
        let activity = makeClient(transport).activity
        #expect(try await activity.subscription(to: "octocat", "Hello-World")?.isSubscribed == true)
        #expect(try await activity.subscription(to: "octocat", "Hello-World") == nil)
        try await activity.watch("octocat", "Hello-World")
        try await activity.watch("octocat", "Hello-World", ignored: true)
        try await activity.unwatch("octocat", "Hello-World")
        #expect(transport.requests[2].route == "PUT /repos/octocat/Hello-World/subscription")
        #expect(transport.requests[2].jsonBody == ["subscribed": true, "ignored": false])
        #expect(transport.requests[3].jsonBody == ["subscribed": false, "ignored": true])
        #expect(transport.requests[4].route == "DELETE /repos/octocat/Hello-World/subscription")
    }
}
