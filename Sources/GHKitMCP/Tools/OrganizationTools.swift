import GHKit
import MCP

/// Organizations: profiles, members, outside collaborators, and invitations.
enum OrganizationTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reads + writes
    }

    static let org: [String: MCP.Value] = ["org": Schema.string("The organization's login.")]
    static let member: [String: MCP.Value] = ["user": Schema.string("The person's login.")]

    static let memberRoles: KeyValuePairs<String, MemberRoleFilter> = ["all": .all, "admin": .admin, "member": .member]
    static let memberFilters: KeyValuePairs<String, MemberFilter> = [
        "all": .all, "2fa_disabled": .twoFactorDisabled, "2fa_insecure": .twoFactorInsecure,
    ]
    static let organizationRoles: KeyValuePairs<String, OrganizationRole> = ["member": .member, "admin": .admin]
    static let invitationRoles: KeyValuePairs<String, InvitationRole> = [
        "direct_member": .directMember, "admin": .admin, "billing_manager": .billingManager, "reinstate": .reinstate,
    ]

    // MARK: Reading

    static let reads: [GitHubTool] = [
        GitHubTool(
            "list_organizations",
            title: "List organizations",
            description: "Organizations the signed-in user belongs to, or a user's public memberships.",
            schema: Schema.object(["user": Schema.string("A user's login. Defaults to the signed-in user.")], Schema.paging)
        ) { arguments, context in
            let organizations = context.client.organizations
            let perPage = try arguments.perPage
            if let user = try arguments.optionalString("user") {
                return try await .page(organizations.list(of: user, perPage: perPage), arguments, context)
            }
            return try await .page(organizations.list(perPage: perPage), arguments, context)
        },
        GitHubTool(
            "get_organization",
            title: "Get organization",
            description: "An organization's profile, plan, and member settings. Some settings appear only to owners.",
            schema: Schema.object(org, required: ["org"])
        ) { arguments, context in
            try .json(await context.client.organizations.organization(arguments.string("org")))
        },
        GitHubTool(
            "list_organization_members",
            title: "List organization members",
            description: "An organization's members. Members who hide their membership appear only to other members.",
            schema: Schema.object(
                org,
                [
                    "role": Schema.oneOf(memberRoles, "Only members with this role. Defaults to `all`."),
                    "filter": Schema.oneOf(memberFilters, "Owners only: members without secure two-factor authentication."),
                ],
                Schema.paging,
                required: ["org"]
            )
        ) { arguments, context in
            let list = try context.client.organizations.members(
                of: arguments.string("org"),
                filter: arguments.choice("filter", from: memberFilters) ?? .all,
                role: arguments.choice("role", from: memberRoles) ?? .all,
                perPage: arguments.perPage
            )
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_organization_membership",
            title: "Get organization membership",
            description: """
                Someone's role in an organization and whether their invitation is still pending. Leave out `user` \
                for the signed-in user's own membership.
                """,
            schema: Schema.object(org, ["user": Schema.string("The person's login. Defaults to the signed-in user.")], required: ["org"])
        ) { arguments, context in
            let org = try arguments.string("org")
            if let user = try arguments.optionalString("user") {
                return try .json(await context.client.organizations.membership(of: user, in: org))
            }
            return try .json(await context.client.organizations.membership(in: org))
        },
        GitHubTool(
            "list_outside_collaborators",
            title: "List outside collaborators",
            description: "People with access to some of an organization's repositories who aren't members.",
            schema: Schema.object(org, Schema.paging, required: ["org"])
        ) { arguments, context in
            let list = try context.client.organizations.outsideCollaborators(of: arguments.string("org"), perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_organization_invitations",
            title: "List organization invitations",
            description: "Invitations waiting for an answer, or ones that failed or expired when `failed` is true.",
            schema: Schema.object(
                org, ["failed": Schema.boolean("Failed or expired invitations instead. Defaults to false.")], Schema.paging,
                required: ["org"])
        ) { arguments, context in
            let (org, perPage) = (try arguments.string("org"), try arguments.perPage)
            let organizations = context.client.organizations
            if try arguments.bool("failed", default: false) {
                return try await .page(organizations.failedInvitations(of: org, perPage: perPage), arguments, context)
            }
            return try await .page(organizations.invitations(of: org, perPage: perPage), arguments, context)
        },
    ]

    // MARK: Writing

    static let writes: [GitHubTool] = [
        GitHubTool(
            "update_organization",
            title: "Update organization",
            kind: .write,
            idempotent: true,
            description: "Changes an organization's public profile. Requires an owner. Fields you leave out stay as they are.",
            schema: Schema.object(
                org,
                [
                    "name": Schema.string("The display name."),
                    "description": Schema.string("A short description."),
                    "company": Schema.string("The company."),
                    "location": Schema.string("Where it is."),
                    "blog": Schema.string("A website URL."),
                    "email": Schema.string("The public email."),
                    "billingEmail": Schema.string("The billing email, which isn't public."),
                ],
                required: ["org"]
            )
        ) { arguments, context in
            let changes = OrganizationUpdate(
                name: try arguments.optionalString("name"),
                description: try arguments.optionalString("description"),
                company: try arguments.optionalString("company"),
                blog: try arguments.optionalString("blog"),
                location: try arguments.optionalString("location"),
                email: try arguments.optionalString("email"),
                billingEmail: try arguments.optionalString("billingEmail")
            )
            guard changes != OrganizationUpdate() else { throw ToolFailure("Pass at least one field to change.") }
            return try .json(await context.client.organizations.update(arguments.string("org"), changes))
        },
        GitHubTool(
            "set_organization_membership",
            title: "Set organization membership",
            kind: .write,
            idempotent: true,
            description: """
                Adds someone to an organization or changes their role. People who aren't members yet get an \
                invitation and join once they accept.
                """,
            schema: Schema.object(
                org, member, ["role": Schema.oneOf(organizationRoles, "Their role. Defaults to `member`.")],
                required: ["org", "user"])
        ) { arguments, context in
            try .json(
                await context.client.organizations.setMembership(
                    of: arguments.string("user"), in: arguments.string("org"),
                    role: arguments.choice("role", from: organizationRoles) ?? .member))
        },
        GitHubTool(
            "remove_organization_member",
            title: "Remove organization member",
            kind: .destructive,
            idempotent: true,
            description: """
                Removes someone from an organization and all its teams, or cancels their pending invitation. They \
                lose access to the organization's private repositories.
                """,
            schema: Schema.object(org, member, required: ["org", "user"])
        ) { arguments, context in
            let (org, user) = (try arguments.string("org"), try arguments.string("user"))
            try await context.client.organizations.removeMembership(of: user, from: org)
            return .message("Removed \(user) from \(org).")
        },
        GitHubTool(
            "invite_to_organization",
            title: "Invite to organization",
            kind: .write,
            description: "Invites someone to an organization by user ID or email, optionally into some of its teams.",
            schema: Schema.object(
                org,
                [
                    "userID": Schema.integer("The invitee's numeric user ID, from `get_user`."),
                    "email": Schema.string("The invitee's email, for people without a known account."),
                    "role": Schema.oneOf(invitationRoles, "Their role. Defaults to `direct_member`."),
                    "teamIDs": Schema.array(of: ["type": "integer"], "IDs of teams they join when they accept."),
                ],
                required: ["org"]
            )
        ) { arguments, context in
            let invitee: NewOrganizationInvitation.Invitee
            switch (try arguments.optionalInt("userID"), try arguments.optionalString("email")) {
            case (let id?, nil): invitee = .user(id: id)
            case (nil, let email?): invitee = .email(email)
            default: throw ToolFailure("Pass `userID` or `email`, not both.")
            }
            let invitation = NewOrganizationInvitation(
                invitee, role: try arguments.choice("role", from: invitationRoles) ?? .directMember, teamIDs: try arguments.ints("teamIDs"))
            return try .json(await context.client.organizations.invite(invitation, to: arguments.string("org")))
        },
        GitHubTool(
            "cancel_organization_invitation",
            title: "Cancel organization invitation",
            kind: .destructive,
            idempotent: true,
            description: "Cancels a pending invitation, from `list_organization_invitations`.",
            schema: Schema.object(org, ["invitationID": Schema.integer("The invitation's ID.")], required: ["org", "invitationID"])
        ) { arguments, context in
            let (org, id) = (try arguments.string("org"), try arguments.int("invitationID"))
            try await context.client.organizations.cancelInvitation(id: id, in: org)
            return .message("Canceled invitation \(id) to \(org).")
        },
        GitHubTool(
            "accept_organization_invitation",
            title: "Accept organization invitation",
            kind: .write,
            idempotent: true,
            description: "Accepts the signed-in user's pending invitation to an organization.",
            schema: Schema.object(org, required: ["org"])
        ) { arguments, context in
            try .json(await context.client.organizations.acceptInvitation(to: arguments.string("org")))
        },
    ]
}
