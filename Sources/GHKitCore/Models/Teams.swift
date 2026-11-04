import Foundation

/// A role a team can have on a repository: `pull`, `triage`, `push`, `maintain`, `admin`, or a custom role's name.
public struct RepositoryRole: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pull: Self = "pull"
    public static let triage: Self = "triage"
    public static let push: Self = "push"
    public static let maintain: Self = "maintain"
    public static let admin: Self = "admin"
}
