import GHKit
import MCP

/// Teams: members, child teams, and repository access.
enum TeamTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reads + writes
    }

    static let team: [String: MCP.Value] = [
        "org": Schema.string("The organization's login."),
        "team": Schema.string("The team's slug, such as `ios-engineers`."),
    ]
    static let member: [String: MCP.Value] = ["user": Schema.string("The person's login.")]
    static let teamRepository: [String: MCP.Value] = [
        "owner": Schema.string("The account that owns the repository."),
        "repo": Schema.string("The repository name."),
    ]

    static let memberRoles: KeyValuePairs<String, TeamRoleFilter> = ["all": .all, "member": .member, "maintainer": .maintainer]
    static let roles: KeyValuePairs<String, TeamRole> = ["member": .member, "maintainer": .maintainer]
    static let privacies: KeyValuePairs<String, TeamPrivacy> = ["closed": .closed, "secret": .secret]
    static let repositoryRoles: KeyValuePairs<String, RepositoryRole> = [
        "pull": .pull, "triage": .triage, "push": .push, "maintain": .maintain, "admin": .admin,
    ]

    static func slug(_ arguments: ToolArguments) throws(ToolFailure) -> (team: String, org: String) {
        (try arguments.string("team"), try arguments.string("org"))
    }

    // MARK: Reading

    static let reads: [GitHubTool] = [
        GitHubTool(
            "list_teams",
            title: "List teams",
            description: "Teams in an organization that the signed-in user can see, or the teams they belong to across organizations.",
            schema: Schema.object(["org": Schema.string("An organization's login. Defaults to the signed-in user's own teams.")], Schema.paging)
        ) { arguments, context in
            let teams = context.client.teams
            let perPage = try arguments.perPage
            if let org = try arguments.optionalString("org") {
                return try await .page(teams.list(in: org, perPage: perPage), arguments, context)
            }
            return try await .page(teams.mine(perPage: perPage), arguments, context)
        },
        GitHubTool(
            "get_team",
            title: "Get team",
            description: "One team with its description, privacy, parent, and member and repository counts.",
            schema: Schema.object(team, required: ["org", "team"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            return try .json(await context.client.teams.team(team, in: org))
        },
        GitHubTool(
            "list_team_members",
            title: "List team members",
            description: "A team's members, including members of its child teams.",
            schema: Schema.object(
                team, ["role": Schema.oneOf(memberRoles, "Only members with this role. Defaults to `all`.")], Schema.paging,
                required: ["org", "team"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            let list = try context.client.teams.members(
                of: team, in: org, role: arguments.choice("role", from: memberRoles) ?? .all, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_team_membership",
            title: "Get team membership",
            description: "Someone's role on a team and whether their invitation is still pending.",
            schema: Schema.object(team, member, required: ["org", "team", "user"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            return try .json(await context.client.teams.membership(of: arguments.string("user"), on: team, in: org))
        },
        GitHubTool(
            "list_child_teams",
            title: "List child teams",
            description: "Teams nested directly under a team.",
            schema: Schema.object(team, Schema.paging, required: ["org", "team"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            return try await .page(context.client.teams.childTeams(of: team, in: org, perPage: arguments.perPage), arguments, context)
        },
        GitHubTool(
            "list_team_repositories",
            title: "List team repositories",
            description: "Repositories a team can access, with the team's permissions on each.",
            schema: Schema.object(team, Schema.paging, required: ["org", "team"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            return try await .page(context.client.teams.repositories(of: team, in: org, perPage: arguments.perPage), arguments, context)
        },
    ]

    // MARK: Writing

    static let writes: [GitHubTool] = [
        GitHubTool(
            "create_team",
            title: "Create team",
            kind: .write,
            description: "Creates a team in an organization. The signed-in user becomes a maintainer.",
            schema: Schema.object(
                [
                    "org": Schema.string("The organization's login."),
                    "name": Schema.string("The team's name."),
                    "description": Schema.string("A short description."),
                    "privacy": Schema.oneOf(privacies, "`closed` teams are visible to every member; `secret` ones only to their members."),
                    "maintainers": Schema.array(of: ["type": "string"], "Logins of members to make maintainers."),
                    "repositories": Schema.array(of: ["type": "string"], "Repositories to give the team, as `owner/name`."),
                    "parentTeamID": Schema.integer("The numeric ID of the team to nest it under."),
                ],
                required: ["org", "name"]
            )
        ) { arguments, context in
            let team = NewTeam(
                name: try arguments.string("name"),
                description: try arguments.optionalString("description"),
                maintainers: try arguments.strings("maintainers"),
                repositoryNames: try arguments.strings("repositories"),
                privacy: try arguments.choice("privacy", from: privacies),
                parentTeamID: try arguments.optionalInt("parentTeamID")
            )
            return try .json(await context.client.teams.create(team, in: arguments.string("org")))
        },
        GitHubTool(
            "update_team",
            title: "Update team",
            kind: .write,
            idempotent: true,
            description: "Changes a team's name, description, privacy, or parent. Fields you leave out stay as they are.",
            schema: Schema.object(
                team,
                [
                    "name": Schema.string("A new name. This also changes the slug."),
                    "description": Schema.string("A new description."),
                    "privacy": Schema.oneOf(privacies, "The new privacy."),
                    "parentTeamID": Schema.integer("The numeric ID of a new parent team."),
                    "topLevel": Schema.boolean("Remove the parent so the team is top level."),
                ],
                required: ["org", "team"]
            )
        ) { arguments, context in
            let parent: TeamUpdate.Parent?
            switch (try arguments.optionalInt("parentTeamID"), try arguments.bool("topLevel", default: false)) {
            case (_?, true): throw ToolFailure("Pass `parentTeamID` or `topLevel`, not both.")
            case (let id?, false): parent = .team(id: id)
            case (nil, true): parent = .topLevel
            case (nil, false): parent = nil
            }
            let changes = TeamUpdate(
                name: try arguments.optionalString("name"),
                description: try arguments.optionalString("description"),
                privacy: try arguments.choice("privacy", from: privacies),
                parent: parent
            )
            guard changes != TeamUpdate() else { throw ToolFailure("Pass at least one field to change.") }
            let (team, org) = try slug(arguments)
            return try .json(await context.client.teams.update(team, in: org, changes))
        },
        GitHubTool(
            "delete_team",
            title: "Delete team",
            kind: .destructive,
            idempotent: true,
            description: "Deletes a team and all of its child teams. Members keep any access they have through other teams.",
            schema: Schema.object(team, required: ["org", "team"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            try await context.client.teams.delete(team, in: org)
            return .message("Deleted team \(org)/\(team).")
        },
        GitHubTool(
            "set_team_membership",
            title: "Set team membership",
            kind: .write,
            idempotent: true,
            description: """
                Adds someone to a team or changes their role. People outside the organization get an invitation to \
                the organization first.
                """,
            schema: Schema.object(
                team, member, ["role": Schema.oneOf(roles, "Their role. Defaults to `member`.")], required: ["org", "team", "user"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            return try .json(
                await context.client.teams.setMembership(
                    of: arguments.string("user"), on: team, in: org, role: arguments.choice("role", from: roles) ?? .member))
        },
        GitHubTool(
            "remove_team_membership",
            title: "Remove team membership",
            kind: .destructive,
            idempotent: true,
            description: "Removes someone from a team. They stay in the organization.",
            schema: Schema.object(team, member, required: ["org", "team", "user"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            let user = try arguments.string("user")
            try await context.client.teams.removeMembership(of: user, from: team, in: org)
            return .message("Removed \(user) from \(org)/\(team).")
        },
        GitHubTool(
            "set_team_repository_role",
            title: "Set team repository role",
            kind: .write,
            idempotent: true,
            description: "Gives a team access to a repository, or changes its role there.",
            schema: Schema.object(
                team, teamRepository, ["role": Schema.oneOf(repositoryRoles, "The team's role on the repository.")],
                required: ["org", "team", "owner", "repo", "role"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            let (owner, repo) = (try arguments.string("owner"), try arguments.string("repo"))
            guard let role = try arguments.choice("role", from: repositoryRoles) else {
                throw ToolFailure("Missing required argument `role`.")
            }
            try await context.client.teams.setRepositoryRole(role, on: owner, repo, for: team, in: org)
            return .message("Gave \(org)/\(team) the \(role.rawValue) role on \(owner)/\(repo).")
        },
        GitHubTool(
            "remove_team_repository",
            title: "Remove team repository",
            kind: .destructive,
            idempotent: true,
            description: "Takes a repository away from a team. Members keep any access they have some other way.",
            schema: Schema.object(team, teamRepository, required: ["org", "team", "owner", "repo"])
        ) { arguments, context in
            let (team, org) = try slug(arguments)
            let (owner, repo) = (try arguments.string("owner"), try arguments.string("repo"))
            try await context.client.teams.removeRepository(owner, repo, from: team, in: org)
            return .message("Removed \(owner)/\(repo) from \(org)/\(team).")
        },
    ]
}
