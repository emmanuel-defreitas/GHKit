import GHKit
import MCP

/// Users: profiles, followers, and following.
enum UserTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reads + writes
    }

    static let optionalUser: [String: MCP.Value] = ["user": Schema.string("A user's login. Defaults to the signed-in user.")]

    // MARK: Reading

    static let reads: [GitHubTool] = [
        GitHubTool(
            "get_user",
            title: "Get user",
            description: """
                A user's or organization's public profile: name, bio, company, location, and counts of repositories \
                and followers. Pass `login`, or `id`, which survives renames.
                """,
            schema: Schema.object([
                "login": Schema.string("The user's login."),
                "id": Schema.integer("The user's numeric ID."),
            ])
        ) { arguments, context in
            switch (try arguments.optionalString("login"), try arguments.optionalInt("id")) {
            case (let login?, nil): return try .json(await context.client.users.user(login))
            case (nil, let id?): return try .json(await context.client.users.user(id: id))
            default: throw ToolFailure("Pass `login` or `id`, not both.")
            }
        },
        GitHubTool(
            "list_followers",
            title: "List followers",
            description: "People who follow a user.",
            schema: Schema.object(optionalUser, Schema.paging)
        ) { arguments, context in
            let users = context.client.users
            let perPage = try arguments.perPage
            if let user = try arguments.optionalString("user") {
                return try await .page(users.followers(of: user, perPage: perPage), arguments, context)
            }
            return try await .page(users.followers(perPage: perPage), arguments, context)
        },
        GitHubTool(
            "list_following",
            title: "List following",
            description: "People a user follows.",
            schema: Schema.object(optionalUser, Schema.paging)
        ) { arguments, context in
            let users = context.client.users
            let perPage = try arguments.perPage
            if let user = try arguments.optionalString("user") {
                return try await .page(users.following(of: user, perPage: perPage), arguments, context)
            }
            return try await .page(users.following(perPage: perPage), arguments, context)
        },
    ]

    // MARK: Writing

    static let writes: [GitHubTool] = [
        GitHubTool(
            "update_profile",
            title: "Update profile",
            kind: .write,
            idempotent: true,
            description: "Changes the signed-in user's public profile. Fields you leave out stay as they are.",
            schema: Schema.object([
                "name": Schema.string("The display name."),
                "bio": Schema.string("A short bio."),
                "company": Schema.string("The company."),
                "location": Schema.string("Where they are."),
                "blog": Schema.string("A website URL."),
                "twitterUsername": Schema.string("An X (Twitter) username, without the @."),
                "email": Schema.string("The public email. It must be a verified email on the account."),
                "hireable": Schema.boolean("Whether they're open to job offers."),
            ])
        ) { arguments, context in
            let changes = UserProfileUpdate(
                name: try arguments.optionalString("name"),
                email: try arguments.optionalString("email"),
                blog: try arguments.optionalString("blog"),
                twitterUsername: try arguments.optionalString("twitterUsername"),
                company: try arguments.optionalString("company"),
                location: try arguments.optionalString("location"),
                hireable: try arguments.optionalBool("hireable"),
                bio: try arguments.optionalString("bio")
            )
            guard changes != UserProfileUpdate() else { throw ToolFailure("Pass at least one field to change.") }
            return try .json(await context.client.users.updateProfile(changes))
        },
        GitHubTool(
            "follow_user",
            title: "Follow user",
            kind: .write,
            idempotent: true,
            description: "Follows a user as the signed-in user.",
            schema: Schema.object(["user": Schema.string("The user's login.")], required: ["user"])
        ) { arguments, context in
            let user = try arguments.string("user")
            try await context.client.users.follow(user)
            return .message("Followed \(user).")
        },
        GitHubTool(
            "unfollow_user",
            title: "Unfollow user",
            kind: .write,
            idempotent: true,
            description: "Stops following a user.",
            schema: Schema.object(["user": Schema.string("The user's login.")], required: ["user"])
        ) { arguments, context in
            let user = try arguments.string("user")
            try await context.client.users.unfollow(user)
            return .message("Unfollowed \(user).")
        },
    ]
}
