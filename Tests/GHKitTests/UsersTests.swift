import Foundation
import Testing

@testable import GHKit

@Suite("Users")
struct UsersTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func accountModelsDecode() throws {
        let emails = try decoder.decode([UserEmail].self, from: loadFixture("email-items"))
        #expect(emails.count == 3)
        #expect(emails[0].visibility == "public")
        #expect(emails[1].visibility == nil)

        let gpg = try decoder.decode(GPGKey.self, from: loadFixture("gpg-key"))
        #expect(gpg.keyID == "3262EFF25BA0D270")
        #expect(gpg.subkeys?.first?.canEncryptComms == true)
        #expect(gpg.emails?.first?.verified == true)

        let key = try decoder.decode(SSHKey.self, from: loadFixture("key"))
        #expect(key.readOnly == false)
        let publicKeys = try decoder.decode([SSHKey].self, from: loadFixture("key-simple-items"))
        #expect(publicKeys.first?.title == nil)

        let signing = try decoder.decode(SSHSigningKey.self, from: loadFixture("ssh-signing-key"))
        #expect(signing.id == 2)

        let social = try decoder.decode([SocialAccount].self, from: loadFixture("social-account-items"))
        #expect(social.first?.provider == "twitter")
    }

    // MARK: Requests

    @Test func updateProfileSendsOnlyChangedFields() async throws {
        let transport = MockTransport(.fixture("private-user"))
        _ = try await makeClient(transport).users.updateProfile(UserProfileUpdate(hireable: true, bio: "Swift"))
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "PATCH")
        #expect(request.path == "/user")
        #expect(request.jsonBody == ["bio": "Swift", "hireable": true])
    }

    @Test func listUsersSince() async throws {
        let transport = MockTransport(.fixture("simple-user-items"))
        let users = try await makeClient(transport).users.all(since: 42).collect()
        #expect(!users.isEmpty)
        #expect(transport.requests.first?.queryItems == ["since": "42", "per_page": "100"])
    }

    @Test func hovercardSendsSubject() async throws {
        let transport = MockTransport(.fixture("hovercard"))
        let contexts = try await makeClient(transport).users.hovercard(for: "octocat", about: .pullRequest(id: 7))
        #expect(contexts == [HovercardContext(message: "Owns this repository", octicon: "repo")])
        let request = try #require(transport.requests.first)
        #expect(request.path == "/users/octocat/hovercard")
        #expect(request.queryItems == ["subject_type": "pull_request", "subject_id": "7"])
    }

    @Test(arguments: [(204, true), (404, false)])
    func checkEndpointsMapStatusToBool(status: Int, expected: Bool) async throws {
        let transport = MockTransport(MockResponse(status: status))
        let users = makeClient(transport).users
        #expect(try await users.isFollowing("octocat") == expected)
        #expect(try await users.isFollowing("hubot", by: "octocat") == expected)
        #expect(try await users.isBlocked("spammer") == expected)
        #expect(transport.requests.map(\.path) == ["/user/following/octocat", "/users/octocat/following/hubot", "/user/blocks/spammer"])
    }

    @Test func checkEndpointsStillThrowOtherErrors() async {
        let transport = MockTransport(.json(#"{"message":"Requires authentication"}"#, status: 401))
        await #expect(throws: GitHubError.self) {
            _ = try await makeClient(transport).users.isFollowing("octocat")
        }
    }

    @Test func followAndBlockUsePutAndDelete() async throws {
        let transport = MockTransport(.noContent())
        let users = makeClient(transport).users
        try await users.follow("octocat")
        try await users.unfollow("octocat")
        try await users.block("spammer")
        try await users.unblock("spammer")
        #expect(
            transport.requests.map { "\($0.httpMethod!) \($0.path)" } == [
                "PUT /user/following/octocat", "DELETE /user/following/octocat",
                "PUT /user/blocks/spammer", "DELETE /user/blocks/spammer",
            ])
    }

    @Test func emailChanges() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "DELETE" ? .noContent() : .fixture("email-items")
        }
        let users = makeClient(transport).users
        _ = try await users.addEmails(["mona@github.com"])
        try await users.deleteEmails(["old@example.com"])
        _ = try await users.setPrimaryEmailVisibility(.private)
        #expect(transport.requests[0].jsonBody == ["emails": ["mona@github.com"]])
        #expect(transport.requests[1].httpMethod == "DELETE")
        #expect(transport.requests[1].jsonBody == ["emails": ["old@example.com"]])
        #expect(transport.requests[2].path == "/user/email/visibility")
        #expect(transport.requests[2].jsonBody == ["visibility": "private"])
    }

    @Test func addKeys() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case "/user/gpg_keys": .fixture("gpg-key", status: 201)
            case "/user/keys": .fixture("key", status: 201)
            default: .fixture("ssh-signing-key", status: 201)
            }
        }
        let users = makeClient(transport).users
        _ = try await users.addGPGKey(armoredPublicKey: "-----BEGIN PGP…", name: "Laptop")
        _ = try await users.addSSHKey("ssh-ed25519 AAAA", title: "Laptop")
        _ = try await users.addSSHSigningKey("ssh-ed25519 BBBB")
        #expect(transport.requests[0].jsonBody == ["armored_public_key": "-----BEGIN PGP…", "name": "Laptop"])
        #expect(transport.requests[1].jsonBody == ["key": "ssh-ed25519 AAAA", "title": "Laptop"])
        #expect(transport.requests[2].path == "/user/ssh_signing_keys")
        #expect(transport.requests[2].jsonBody == ["key": "ssh-ed25519 BBBB"])
    }

    @Test func keyListsForOtherUsers() async throws {
        let transport = MockTransport(.json("[]"))
        let users = makeClient(transport).users
        _ = try await users.gpgKeys(of: "octocat").collect()
        _ = try await users.sshKeys(of: "octocat").collect()
        _ = try await users.sshSigningKeys(of: "octocat").collect()
        _ = try await users.socialAccounts(of: "octocat").collect()
        _ = try await users.followers(of: "octocat").collect()
        _ = try await users.following(of: "octocat").collect()
        #expect(
            transport.requests.map(\.path) == [
                "/users/octocat/gpg_keys", "/users/octocat/keys", "/users/octocat/ssh_signing_keys",
                "/users/octocat/social_accounts", "/users/octocat/followers", "/users/octocat/following",
            ])
    }

    @Test func socialAccountChanges() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "DELETE" ? .noContent() : .fixture("social-account-items", status: 201)
        }
        let users = makeClient(transport).users
        let url = URL(string: "https://mastodon.social/@octocat")!
        _ = try await users.addSocialAccounts([url])
        try await users.deleteSocialAccounts([url])
        #expect(transport.requests[0].jsonBody == ["account_urls": ["https://mastodon.social/@octocat"]])
        #expect(transport.requests[1].httpMethod == "DELETE")
    }
}
