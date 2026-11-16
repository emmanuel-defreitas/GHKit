import Foundation
import GHKitCore

/// A check on a commit, such as a CI job or a linter, reported by a GitHub App (`check-run`).
public struct CheckRun: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    public var headSHA: String
    /// The app's own ID for the run.
    public var externalID: String?
    public var status: CheckStatus
    /// Set once ``status`` is ``CheckStatus/completed``.
    public var conclusion: CheckConclusion?
    public var startedAt: Date?
    public var completedAt: Date?
    public var output: Output
    /// The suite the run belongs to.
    public var checkSuite: SuiteReference?
    /// The app that reported the run.
    public var app: GitHubApp?
    /// Open pull requests whose head is ``headSHA``.
    public var pullRequests: [PullRequestReference]
    public var url: URL
    public var htmlURL: URL?
    /// The app's page for the run.
    public var detailsURL: URL?

    /// What a check run reports.
    public struct Output: Sendable, Hashable, Codable {
        public var title: String?
        /// Markdown.
        public var summary: String?
        /// Markdown.
        public var text: String?
        public var annotationsCount: Int
        public var annotationsURL: URL

        enum CodingKeys: String, CodingKey {
            case title, summary, text
            case annotationsCount = "annotations_count"
            case annotationsURL = "annotations_url"
        }
    }

    /// The check suite a run belongs to.
    public struct SuiteReference: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, output, app, url
        case nodeID = "node_id"
        case headSHA = "head_sha"
        case externalID = "external_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case checkSuite = "check_suite"
        case pullRequests = "pull_requests"
        case htmlURL = "html_url"
        case detailsURL = "details_url"
    }
}

/// How serious a check run annotation is.
public struct CheckAnnotationLevel: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let notice: Self = "notice"
    public static let warning: Self = "warning"
    public static let failure: Self = "failure"
}

/// A note a check run left on lines of a file (`check-annotation`).
public struct CheckAnnotation: Sendable, Hashable, Codable {
    public var path: String
    public var startLine: Int
    public var endLine: Int
    public var startColumn: Int?
    public var endColumn: Int?
    public var level: CheckAnnotationLevel?
    public var title: String?
    public var message: String?
    public var rawDetails: String?
    /// The file at the run's commit.
    public var blobURL: URL

    enum CodingKeys: String, CodingKey {
        case path, title, message
        case startLine = "start_line"
        case endLine = "end_line"
        case startColumn = "start_column"
        case endColumn = "end_column"
        case level = "annotation_level"
        case rawDetails = "raw_details"
        case blobURL = "blob_href"
    }
}

/// What a check run reports, for creating or updating one.
public struct NewCheckRunOutput: Sendable, Hashable, Encodable {
    public var title: String
    /// Markdown, up to 65,535 characters.
    public var summary: String
    /// Markdown, up to 65,535 characters.
    public var text: String?
    /// Up to 50 per request. Send more with further updates; GitHub adds them to the earlier ones.
    public var annotations: [NewCheckAnnotation]
    public var images: [Image]

    /// An image shown in the run's output.
    public struct Image: Sendable, Hashable, Encodable {
        public var alt: String
        public var url: URL
        public var caption: String?

        public init(alt: String, url: URL, caption: String? = nil) {
            self.alt = alt
            self.url = url
            self.caption = caption
        }

        enum CodingKeys: String, CodingKey {
            case alt, caption
            case url = "image_url"
        }
    }

    public init(title: String, summary: String, text: String? = nil, annotations: [NewCheckAnnotation] = [], images: [Image] = []) {
        self.title = title
        self.summary = summary
        self.text = text
        self.annotations = annotations
        self.images = images
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(summary, forKey: .summary)
        try c.encodeIfPresent(text, forKey: .text)
        if !annotations.isEmpty { try c.encode(annotations, forKey: .annotations) }
        if !images.isEmpty { try c.encode(images, forKey: .images) }
    }

    enum CodingKeys: String, CodingKey {
        case title, summary, text, annotations, images
    }
}

/// A note to leave on lines of a file.
public struct NewCheckAnnotation: Sendable, Hashable, Encodable {
    public var path: String
    public var startLine: Int
    public var endLine: Int
    /// Only when the annotation is on one line.
    public var startColumn: Int?
    public var endColumn: Int?
    public var level: CheckAnnotationLevel
    public var message: String
    public var title: String?
    public var rawDetails: String?

    public init(
        path: String, lines: ClosedRange<Int>, columns: ClosedRange<Int>? = nil, level: CheckAnnotationLevel, message: String,
        title: String? = nil, rawDetails: String? = nil
    ) {
        self.path = path
        self.startLine = lines.lowerBound
        self.endLine = lines.upperBound
        self.startColumn = columns?.lowerBound
        self.endColumn = columns?.upperBound
        self.level = level
        self.message = message
        self.title = title
        self.rawDetails = rawDetails
    }

    enum CodingKeys: String, CodingKey {
        case path, message, title
        case startLine = "start_line"
        case endLine = "end_line"
        case startColumn = "start_column"
        case endColumn = "end_column"
        case level = "annotation_level"
        case rawDetails = "raw_details"
    }
}

/// A button on a check run that sends the app a `check_run.requested_action` webhook.
public struct CheckRunAction: Sendable, Hashable, Encodable {
    /// Up to 20 characters.
    public var label: String
    /// Up to 40 characters.
    public var description: String
    /// The app's ID for the action, up to 20 characters.
    public var identifier: String

    public init(label: String, description: String, identifier: String) {
        self.label = label
        self.description = description
        self.identifier = identifier
    }
}

/// A check run to create. Setting a conclusion marks it completed.
public struct NewCheckRun: Sendable, Hashable, Encodable {
    public var name: String
    public var headSHA: String
    /// Defaults to ``CheckStatus/queued``.
    public var status: CheckStatus?
    public var conclusion: CheckConclusion?
    public var startedAt: Date?
    public var completedAt: Date?
    public var output: NewCheckRunOutput?
    /// Up to three buttons.
    public var actions: [CheckRunAction]
    /// The app's page for the run.
    public var detailsURL: URL?
    /// The app's own ID for the run.
    public var externalID: String?

    public init(
        name: String, headSHA: String, status: CheckStatus? = nil, conclusion: CheckConclusion? = nil, startedAt: Date? = nil,
        completedAt: Date? = nil, output: NewCheckRunOutput? = nil, actions: [CheckRunAction] = [], detailsURL: URL? = nil,
        externalID: String? = nil
    ) {
        self.name = name
        self.headSHA = headSHA
        self.status = status
        self.conclusion = conclusion
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.output = output
        self.actions = actions
        self.detailsURL = detailsURL
        self.externalID = externalID
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(headSHA, forKey: .headSHA)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(conclusion, forKey: .conclusion)
        try c.encodeIfPresent(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encodeIfPresent(output, forKey: .output)
        if !actions.isEmpty { try c.encode(actions, forKey: .actions) }
        try c.encodeIfPresent(detailsURL, forKey: .detailsURL)
        try c.encodeIfPresent(externalID, forKey: .externalID)
    }

    enum CodingKeys: String, CodingKey {
        case name, status, conclusion, output, actions
        case headSHA = "head_sha"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case detailsURL = "details_url"
        case externalID = "external_id"
    }
}

/// Changes to a check run. `nil` leaves a field as it is. Setting a conclusion marks it completed.
public struct CheckRunUpdate: Sendable, Hashable, Encodable {
    public var name: String?
    public var status: CheckStatus?
    public var conclusion: CheckConclusion?
    public var startedAt: Date?
    public var completedAt: Date?
    /// Annotations add to the earlier ones; the other fields replace them.
    public var output: NewCheckRunOutput?
    /// Replaces the buttons. `[]` removes them.
    public var actions: [CheckRunAction]?
    public var detailsURL: URL?
    public var externalID: String?

    public init(
        name: String? = nil, status: CheckStatus? = nil, conclusion: CheckConclusion? = nil, startedAt: Date? = nil,
        completedAt: Date? = nil, output: NewCheckRunOutput? = nil, actions: [CheckRunAction]? = nil, detailsURL: URL? = nil,
        externalID: String? = nil
    ) {
        self.name = name
        self.status = status
        self.conclusion = conclusion
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.output = output
        self.actions = actions
        self.detailsURL = detailsURL
        self.externalID = externalID
    }

    enum CodingKeys: String, CodingKey {
        case name, status, conclusion, output, actions
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case detailsURL = "details_url"
        case externalID = "external_id"
    }
}

/// Narrows check run lists.
public struct CheckRunFilter: Sendable, Hashable {
    /// Only runs with exactly this name.
    public var name: String?
    /// ``CheckStatus/queued``, ``CheckStatus/inProgress``, or ``CheckStatus/completed``.
    public var status: CheckStatus?
    /// Adds runs that a newer run with the same name replaced.
    public var includesEarlierRuns: Bool

    public init(name: String? = nil, status: CheckStatus? = nil, includesEarlierRuns: Bool = false) {
        self.name = name
        self.status = status
        self.includesEarlierRuns = includesEarlierRuns
    }

    var query: [URLQueryItem] {
        .query(("check_name", name), ("status", status), ("filter", includesEarlierRuns ? "all" : nil))
    }
}

/// The check runs one app reported for a commit (`check-suite`).
public struct CheckSuite: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var headBranch: String?
    public var headSHA: String
    public var headCommit: SimpleCommit
    public var status: CheckStatus?
    public var conclusion: CheckConclusion?
    /// The commit before a push, for suites a push created.
    public var before: String?
    /// The commit after a push, for suites a push created.
    public var after: String?
    public var app: GitHubApp?
    public var repository: Repository
    public var pullRequests: [PullRequestReference]?
    public var latestCheckRunsCount: Int
    /// Whether ``ChecksAPI/rerequestSuite(id:in:_:)`` can run the suite again.
    public var isRerequestable: Bool?
    /// Whether its check runs can be run again.
    public var areRunsRerequestable: Bool?
    public var url: URL?
    public var checkRunsURL: URL
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, conclusion, before, after, app, repository, url
        case nodeID = "node_id"
        case headBranch = "head_branch"
        case headSHA = "head_sha"
        case headCommit = "head_commit"
        case pullRequests = "pull_requests"
        case latestCheckRunsCount = "latest_check_runs_count"
        case isRerequestable = "rerequestable"
        case areRunsRerequestable = "runs_rerequestable"
        case checkRunsURL = "check_runs_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Which apps' check suites GitHub creates on every push to a repository (`check-suite-preference`).
public struct CheckSuitePreferences: Sendable, Hashable, Codable {
    public var autoTrigger: [AutoTrigger]
    public var repository: Repository

    /// Whether GitHub creates an app's check suites on push.
    public struct AutoTrigger: Sendable, Hashable, Codable {
        public var appID: Int
        public var isEnabled: Bool

        public init(appID: Int, isEnabled: Bool) {
            self.appID = appID
            self.isEnabled = isEnabled
        }

        enum CodingKeys: String, CodingKey {
            case appID = "app_id"
            case isEnabled = "setting"
        }
    }

    enum CodingKeys: String, CodingKey { case preferences, repository }
    enum PreferenceKeys: String, CodingKey { case autoTrigger = "auto_trigger_checks" }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let preferences = try c.nestedContainer(keyedBy: PreferenceKeys.self, forKey: .preferences)
        autoTrigger = try preferences.decodeIfPresent([AutoTrigger].self, forKey: .autoTrigger) ?? []
        repository = try c.decode(Repository.self, forKey: .repository)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        var preferences = c.nestedContainer(keyedBy: PreferenceKeys.self, forKey: .preferences)
        try preferences.encode(autoTrigger, forKey: .autoTrigger)
        try c.encode(repository, forKey: .repository)
    }
}
