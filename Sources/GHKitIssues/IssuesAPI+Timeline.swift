import Foundation
import GHKitCore

extension IssuesAPI {
    /// Everything that happened on an issue or pull request, oldest first: comments, commits, reviews, and events.
    /// `GET /repos/{owner}/{repo}/issues/{issue_number}/timeline`
    /// - Parameter excluding: Kinds of entries to leave out, such as `.labeled`.
    public func timeline(
        of number: Int, in owner: String, _ name: String, excluding: [IssueEventType] = [], perPage: Int = 100
    ) -> Paginated<TimelineEvent> {
        let exclude = excluding.isEmpty ? nil : excluding.map(\.rawValue).joined(separator: ",")
        return client.paginate(
            GitHubRequest(.get, issuePath(number, owner, name, "/timeline"), query: .query(("exclude", exclude), ("per_page", perPage))))
    }
}
