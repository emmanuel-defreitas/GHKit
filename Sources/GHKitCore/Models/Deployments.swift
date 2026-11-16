import Foundation

/// A request to deploy a ref to an environment (`deployment`).
public struct Deployment: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var sha: String
    public var ref: String
    /// Such as `deploy` or `deploy:migrations`.
    public var task: String
    public var environment: String
    /// The environment the deployment was first created for.
    public var originalEnvironment: String?
    public var description: String?
    public var creator: SimpleUser?
    /// Extra data for deployment tools: a JSON object or a string.
    public var payload: JSONValue?
    /// Whether the environment goes away later, such as a review app.
    public var isTransientEnvironment: Bool?
    /// Whether end users use the environment directly.
    public var isProductionEnvironment: Bool?
    /// The app that created the deployment, if any.
    public var performedViaGitHubApp: GitHubApp?
    public var url: URL
    public var statusesURL: URL
    public var repositoryURL: URL
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, sha, ref, task, environment, description, creator, payload, url
        case nodeID = "node_id"
        case originalEnvironment = "original_environment"
        case isTransientEnvironment = "transient_environment"
        case isProductionEnvironment = "production_environment"
        case performedViaGitHubApp = "performed_via_github_app"
        case statusesURL = "statuses_url"
        case repositoryURL = "repository_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// A person or team who can approve deployments.
public enum DeploymentReviewer: Sendable, Hashable, Codable {
    case user(SimpleUser)
    case team(Team)

    enum CodingKeys: String, CodingKey { case type, reviewer }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "Team": self = .team(try c.decode(Team.self, forKey: .reviewer))
        default: self = .user(try c.decode(SimpleUser.self, forKey: .reviewer))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user(let user):
            try c.encode("User", forKey: .type)
            try c.encode(user, forKey: .reviewer)
        case .team(let team):
            try c.encode("Team", forKey: .type)
            try c.encode(team, forKey: .reviewer)
        }
    }
}
