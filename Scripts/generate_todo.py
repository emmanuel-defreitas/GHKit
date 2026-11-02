#!/usr/bin/env python3
"""Regenerates TODO.md from GitHub's OpenAPI description.

Usage:
    curl -sSL -o /tmp/api.json \
      https://raw.githubusercontent.com/github/rest-api-description/main/descriptions/api.github.com/api.github.com.json
    python3 Scripts/generate_todo.py /tmp/api.json > TODO.md

To record progress, edit DONE, IN_PROGRESS and DEFERRED below (keyed by operationId), then rerun.
"""

import json
import sys
from collections import defaultdict
from datetime import date

# operationId -> Swift API that covers it
DONE = {
    # Authentication: users and rate limit
    "users/get-authenticated": "`github.users.authenticated()`, `github.verifyAuthentication()`",
    "users/get-by-username": "`github.users.user(_:)`",
    "users/get-by-id": "`github.users.user(id:)`",
    "rate-limit/get": "`github.rateLimit()`",
    # Users (milestone 2)
    "users/update-authenticated": "`users.updateProfile(_:)`",
    "users/list": "`users.all(since:perPage:)`",
    "users/get-context-for-user": "`users.hovercard(for:about:)`",
    "users/list-followers-for-authenticated-user": "`users.followers()`",
    "users/list-followers-for-user": "`users.followers(of:)`",
    "users/list-followed-by-authenticated-user": "`users.following()`",
    "users/list-following-for-user": "`users.following(of:)`",
    "users/check-person-is-followed-by-authenticated": "`users.isFollowing(_:)`",
    "users/check-following-for-user": "`users.isFollowing(_:by:)`",
    "users/follow": "`users.follow(_:)`",
    "users/unfollow": "`users.unfollow(_:)`",
    "users/list-blocked-by-authenticated-user": "`users.blockedUsers()`",
    "users/check-blocked": "`users.isBlocked(_:)`",
    "users/block": "`users.block(_:)`",
    "users/unblock": "`users.unblock(_:)`",
    "users/list-emails-for-authenticated-user": "`users.emails()`",
    "users/list-public-emails-for-authenticated-user": "`users.publicEmails()`",
    "users/add-email-for-authenticated-user": "`users.addEmails(_:)`",
    "users/delete-email-for-authenticated-user": "`users.deleteEmails(_:)`",
    "users/set-primary-email-visibility-for-authenticated-user": "`users.setPrimaryEmailVisibility(_:)`",
    "users/list-gpg-keys-for-authenticated-user": "`users.gpgKeys()`",
    "users/list-gpg-keys-for-user": "`users.gpgKeys(of:)`",
    "users/get-gpg-key-for-authenticated-user": "`users.gpgKey(id:)`",
    "users/create-gpg-key-for-authenticated-user": "`users.addGPGKey(armoredPublicKey:name:)`",
    "users/delete-gpg-key-for-authenticated-user": "`users.deleteGPGKey(id:)`",
    "users/list-public-ssh-keys-for-authenticated-user": "`users.sshKeys()`",
    "users/list-public-keys-for-user": "`users.sshKeys(of:)`",
    "users/get-public-ssh-key-for-authenticated-user": "`users.sshKey(id:)`",
    "users/create-public-ssh-key-for-authenticated-user": "`users.addSSHKey(_:title:)`",
    "users/delete-public-ssh-key-for-authenticated-user": "`users.deleteSSHKey(id:)`",
    "users/list-ssh-signing-keys-for-authenticated-user": "`users.sshSigningKeys()`",
    "users/list-ssh-signing-keys-for-user": "`users.sshSigningKeys(of:)`",
    "users/get-ssh-signing-key-for-authenticated-user": "`users.sshSigningKey(id:)`",
    "users/create-ssh-signing-key-for-authenticated-user": "`users.addSSHSigningKey(_:title:)`",
    "users/delete-ssh-signing-key-for-authenticated-user": "`users.deleteSSHSigningKey(id:)`",
    "users/list-social-accounts-for-authenticated-user": "`users.socialAccounts()`",
    "users/list-social-accounts-for-user": "`users.socialAccounts(of:)`",
    "users/add-social-account-for-authenticated-user": "`users.addSocialAccounts(_:)`",
    "users/delete-social-account-for-authenticated-user": "`users.deleteSocialAccounts(_:)`",
    # Organizations (milestone 2)
    "orgs/list": "`organizations.all(since:perPage:)`",
    "orgs/list-for-authenticated-user": "`organizations.list(perPage:)`",
    "orgs/list-for-user": "`organizations.list(of:perPage:)`",
    "orgs/get": "`organizations.organization(_:)`",
    "orgs/update": "`organizations.update(_:_:)`",
    "orgs/delete": "`organizations.delete(_:)`",
    "orgs/list-app-installations": "`organizations.installations(of:perPage:)`",
    "orgs/list-members": "`organizations.members(of:filter:role:perPage:)`",
    "orgs/check-membership-for-user": "`organizations.isMember(_:of:)`",
    "orgs/remove-member": "`organizations.removeMember(_:from:)`",
    "orgs/get-membership-for-user": "`organizations.membership(of:in:)`",
    "orgs/set-membership-for-user": "`organizations.setMembership(of:in:role:)`",
    "orgs/remove-membership-for-user": "`organizations.removeMembership(of:from:)`",
    "orgs/list-public-members": "`organizations.publicMembers(of:perPage:)`",
    "orgs/check-public-membership-for-user": "`organizations.isPublicMember(_:of:)`",
    "orgs/set-public-membership-for-authenticated-user": "`organizations.publicizeMembership(of:in:)`",
    "orgs/remove-public-membership-for-authenticated-user": "`organizations.concealMembership(of:in:)`",
    "orgs/list-outside-collaborators": "`organizations.outsideCollaborators(of:filter:perPage:)`",
    "orgs/convert-member-to-outside-collaborator": "`organizations.convertToOutsideCollaborator(_:in:async:)`",
    "orgs/remove-outside-collaborator": "`organizations.removeOutsideCollaborator(_:from:)`",
    "orgs/list-pending-invitations": "`organizations.invitations(of:role:source:perPage:)`",
    "orgs/list-failed-invitations": "`organizations.failedInvitations(of:perPage:)`",
    "orgs/create-invitation": "`organizations.invite(_:to:)`",
    "orgs/cancel-invitation": "`organizations.cancelInvitation(id:in:)`",
    "orgs/list-invitation-teams": "`organizations.invitationTeams(id:in:perPage:)`",
    "orgs/list-blocked-users": "`organizations.blockedUsers(in:perPage:)`",
    "orgs/check-blocked-user": "`organizations.isBlocked(_:in:)`",
    "orgs/block-user": "`organizations.block(_:in:)`",
    "orgs/unblock-user": "`organizations.unblock(_:in:)`",
    "orgs/list-memberships-for-authenticated-user": "`organizations.memberships(state:perPage:)`",
    "orgs/get-membership-for-authenticated-user": "`organizations.membership(in:)`",
    "orgs/update-membership-for-authenticated-user": "`organizations.acceptInvitation(to:)`",
    "orgs/list-webhooks": "`organizations.webhooks(of:perPage:)`",
    "orgs/get-webhook": "`organizations.webhook(id:in:)`",
    "orgs/create-webhook": "`organizations.createWebhook(_:in:)`",
    "orgs/update-webhook": "`organizations.updateWebhook(id:in:_:)`",
    "orgs/delete-webhook": "`organizations.deleteWebhook(id:in:)`",
    "orgs/get-webhook-config-for-org": "`organizations.webhookConfiguration(id:in:)`",
    "orgs/update-webhook-config-for-org": "`organizations.updateWebhookConfiguration(id:in:_:)`",
    "orgs/list-webhook-deliveries": "`organizations.webhookDeliveries(id:in:status:perPage:)`",
    "orgs/get-webhook-delivery": "`organizations.webhookDelivery(_:webhook:in:)`",
    "orgs/redeliver-webhook-delivery": "`organizations.redeliver(_:webhook:in:)`",
    "orgs/ping-webhook": "`organizations.pingWebhook(id:in:)`",
    "orgs/list-org-roles": "`organizations.roles(of:)`",
    "orgs/get-org-role": "`organizations.role(id:in:)`",
    "orgs/list-org-role-teams": "`organizations.teams(withRole:in:perPage:)`",
    "orgs/list-org-role-users": "`organizations.users(withRole:in:perPage:)`",
    "orgs/assign-team-to-org-role": "`organizations.assignRole(_:toTeam:in:)`",
    "orgs/revoke-org-role-team": "`organizations.revokeRole(_:fromTeam:in:)`",
    "orgs/revoke-all-org-roles-team": "`organizations.revokeAllRoles(fromTeam:in:)`",
    "orgs/assign-user-to-org-role": "`organizations.assignRole(_:toUser:in:)`",
    "orgs/revoke-org-role-user": "`organizations.revokeRole(_:fromUser:in:)`",
    "orgs/revoke-all-org-roles-user": "`organizations.revokeAllRoles(fromUser:in:)`",
    "orgs/list-pat-grant-requests": "`organizations.tokenRequests(in:matching:perPage:)`",
    "orgs/list-pat-grant-request-repositories": "`organizations.tokenRequestRepositories(id:in:perPage:)`",
    "orgs/review-pat-grant-request": "`organizations.reviewTokenRequest(id:in:_:reason:)`",
    "orgs/review-pat-grant-requests-in-bulk": "`organizations.reviewTokenRequests(ids:in:_:reason:)`",
    "orgs/list-pat-grants": "`organizations.tokenGrants(in:matching:perPage:)`",
    "orgs/list-pat-grant-repositories": "`organizations.tokenGrantRepositories(id:in:perPage:)`",
    "orgs/update-pat-access": "`organizations.revokeTokenGrant(id:in:)`",
    "orgs/update-pat-accesses": "`organizations.revokeTokenGrants(ids:in:)`",
    "orgs/custom-properties-for-repos-get-organization-definitions": "`organizations.customProperties(of:)`",
    "orgs/custom-properties-for-repos-get-organization-definition": "`organizations.customProperty(_:in:)`",
    "orgs/custom-properties-for-repos-create-or-update-organization-definitions": "`organizations.setCustomProperties(_:in:)`",
    "orgs/custom-properties-for-repos-create-or-update-organization-definition": "`organizations.setCustomProperty(_:in:)`",
    "orgs/custom-properties-for-repos-delete-organization-definition": "`organizations.deleteCustomProperty(_:in:)`",
    "orgs/custom-properties-for-repos-get-organization-values": "`organizations.customPropertyValues(in:repositoryQuery:perPage:)`",
    "orgs/custom-properties-for-repos-create-or-update-organization-values": "`organizations.setCustomPropertyValues(_:onRepositories:in:)`",
    "orgs/external-properties-for-repos-get-organization-app-installations": "`organizations.externalPropertyInstallations(of:)`",
    "orgs/external-properties-for-repos-register-organization-app-installation": "`organizations.registerExternalPropertyInstallation(_:displayName:in:)`",
    "orgs/external-properties-for-repos-get-organization-definitions": "`organizations.externalProperties(of:)`",
    "orgs/external-properties-for-repos-create-or-update-organization-values": "`organizations.setExternalPropertyValues(_:onRepositories:in:)`",
    "orgs/external-properties-for-repos-create-or-update-values-for-organization-property": "`organizations.setExternalPropertyValue(_:values:in:)`",
    "orgs/external-properties-for-repos-delete-organization-values": "`organizations.deleteExternalPropertyValues(_:in:)`",
    "orgs/get-immutable-releases-settings": "`organizations.immutableReleasesSettings(of:)`",
    "orgs/set-immutable-releases-settings": "`organizations.setImmutableReleases(_:in:)`",
    "orgs/get-immutable-releases-settings-repositories": "`organizations.immutableReleasesRepositories(of:perPage:)`",
    "orgs/set-immutable-releases-settings-repositories": "`organizations.setImmutableReleasesRepositories(_:in:)`",
    "orgs/enable-selected-repository-immutable-releases-organization": "`organizations.enableImmutableReleases(forRepository:in:)`",
    "orgs/disable-selected-repository-immutable-releases-organization": "`organizations.disableImmutableReleases(forRepository:in:)`",
    "api-insights/get-summary-stats": "`organizations.apiUsageSummary(in:for:during:)`",
    "api-insights/get-summary-stats-by-user": "`organizations.apiUsageSummary(in:for:during:)`",
    "api-insights/get-summary-stats-by-actor": "`organizations.apiUsageSummary(in:for:during:)`",
    "api-insights/get-time-stats": "`organizations.apiUsageOverTime(in:for:during:every:)`",
    "api-insights/get-time-stats-by-user": "`organizations.apiUsageOverTime(in:for:during:every:)`",
    "api-insights/get-time-stats-by-actor": "`organizations.apiUsageOverTime(in:for:during:every:)`",
    "api-insights/get-route-stats-by-actor": "`organizations.apiRouteUsage(in:by:during:sortedBy:ascending:routeContaining:perPage:)`",
    "api-insights/get-subject-stats": "`organizations.apiSubjectUsage(in:during:sortedBy:ascending:subjectContaining:perPage:)`",
    "api-insights/get-user-stats": "`organizations.apiActorUsage(in:forUser:during:sortedBy:ascending:actorContaining:perPage:)`",
    # Teams (milestone 2)
    "teams/list": "`teams.list(in:type:perPage:)`",
    "teams/list-for-authenticated-user": "`teams.mine(perPage:)`",
    "teams/get-by-name": "`teams.team(_:in:)`",
    "teams/create": "`teams.create(_:in:)`",
    "teams/update-in-org": "`teams.update(_:in:_:)`",
    "teams/delete-in-org": "`teams.delete(_:in:)`",
    "teams/list-child-in-org": "`teams.childTeams(of:in:perPage:)`",
    "teams/list-members-in-org": "`teams.members(of:in:role:perPage:)`",
    "teams/get-membership-for-user-in-org": "`teams.membership(of:on:in:)`",
    "teams/add-or-update-membership-for-user-in-org": "`teams.setMembership(of:on:in:role:)`",
    "teams/remove-membership-for-user-in-org": "`teams.removeMembership(of:from:in:)`",
    "teams/list-pending-invitations-in-org": "`teams.invitations(for:in:perPage:)`",
    "teams/list-repos-in-org": "`teams.repositories(of:in:perPage:)`",
    "teams/check-permissions-for-repo-in-org": "`teams.repository(_:_:for:in:)`",
    "teams/add-or-update-repo-permissions-in-org": "`teams.setRepositoryRole(_:on:_:for:in:)`",
    "teams/remove-repo-in-org": "`teams.removeRepository(_:_:from:in:)`",
    # Repositories (milestone 2)
    "repos/get": "`repositories.repository(_:_:)`",
    "repos/create-for-authenticated-user": "`repositories.create(_:)`",
    "repos/create-in-org": "`repositories.create(_:in:)`",
    "repos/update": "`repositories.update(_:_:_:)`",
    "repos/delete": "`repositories.delete(_:_:)`",
    "repos/transfer": "`repositories.transfer(_:_:to:newName:teamIDs:)`",
    "repos/list-for-authenticated-user": "`repositories.list(matching:sort:ascending:perPage:)`",
    "repos/list-for-user": "`repositories.list(of:type:sort:ascending:perPage:)`",
    "repos/list-for-org": "`repositories.list(in:type:sort:ascending:perPage:)`",
    "repos/list-public": "`repositories.all(since:)`",
    "repos/get-all-topics": "`repositories.topics(_:_:)`",
    "repos/replace-all-topics": "`repositories.replaceTopics(_:on:_:)`",
    "repos/list-languages": "`repositories.languages(_:_:)`",
    "repos/list-tags": "`repositories.tags(_:_:perPage:)`",
    "repos/list-teams": "`repositories.teams(_:_:perPage:)`",
    "repos/list-contributors": "`repositories.contributors(_:_:includeAnonymous:perPage:)`",
    "repos/list-activities": "`repositories.activity(_:_:matching:perPage:)`",
    "repos/get-community-profile-metrics": "`repositories.communityProfile(_:_:)`",
    "repos/get-hash-algorithm": "`repositories.hashAlgorithm(_:_:)`",
    "repos/get-content": "`repositories.contents(_:_:at:ref:)` / `rawContents(_:_:at:ref:)`",
    "repos/create-or-update-file-contents": "`repositories.writeFile(_:to:in:_:)`",
    "repos/delete-file": "`repositories.deleteFile(_:sha:message:in:_:branch:committer:author:)`",
    "repos/get-readme": "`repositories.readme(_:_:in:ref:)`",
    "repos/get-readme-in-directory": "`repositories.readme(_:_:in:ref:)`",
    "licenses/get-for-repo": "`repositories.license(_:_:ref:)`",
    "repos/codeowners-errors": "`repositories.codeownersErrors(_:_:ref:)`",
    "repos/download-tarball-archive": "`repositories.archive(_:_:format:ref:)`",
    "repos/download-zipball-archive": "`repositories.archive(_:_:format:ref:)`",
    "repos/list-forks": "`repositories.forks(_:_:sort:perPage:)`",
    "repos/create-fork": "`repositories.fork(_:_:into:as:defaultBranchOnly:)`",
    "repos/merge-upstream": "`repositories.syncWithUpstream(_:_:branch:)`",
    "repos/create-using-template": "`repositories.create(_:fromTemplate:_:)`",
    "repos/list-collaborators": "`repositories.collaborators(_:_:affiliation:role:perPage:)`",
    "repos/check-collaborator": "`repositories.isCollaborator(_:on:_:)`",
    "repos/get-collaborator-permission-level": "`repositories.permission(of:on:_:)`",
    "repos/add-collaborator": "`repositories.addCollaborator(_:to:_:role:)`",
    "repos/remove-collaborator": "`repositories.removeCollaborator(_:from:_:)`",
    "repos/list-invitations": "`repositories.invitations(_:_:perPage:)`",
    "repos/update-invitation": "`repositories.updateInvitation(id:on:_:permission:)`",
    "repos/delete-invitation": "`repositories.cancelInvitation(id:on:_:)`",
    "repos/list-invitations-for-authenticated-user": "`repositories.myInvitations(perPage:)`",
    "repos/accept-invitation-for-authenticated-user": "`repositories.acceptInvitation(id:)`",
    "repos/decline-invitation-for-authenticated-user": "`repositories.declineInvitation(id:)`",
    "repos/list-deploy-keys": "`repositories.deployKeys(_:_:perPage:)`",
    "repos/get-deploy-key": "`repositories.deployKey(id:in:_:)`",
    "repos/create-deploy-key": "`repositories.addDeployKey(_:title:readOnly:to:_:)`",
    "repos/delete-deploy-key": "`repositories.deleteDeployKey(id:from:_:)`",
    "repos/list-autolinks": "`repositories.autolinks(_:_:)`",
    "repos/get-autolink": "`repositories.autolink(id:in:_:)`",
    "repos/create-autolink": "`repositories.createAutolink(prefix:urlTemplate:alphanumeric:in:_:)`",
    "repos/delete-autolink": "`repositories.deleteAutolink(id:from:_:)`",
    # Authentication: GitHub Apps
    "apps/get-authenticated": "`apps.authenticatedApp()`",
    "apps/get-by-slug": "`apps.app(slug:)`",
    "apps/list-installations": "`apps.installations()`",
    "apps/get-installation": "`apps.installation(id:)`",
    "apps/get-org-installation": "`apps.installation(organization:)`",
    "apps/get-user-installation": "`apps.installation(user:)`",
    "apps/get-repo-installation": "`apps.installation(owner:repository:)`",
    "apps/create-installation-access-token": "`apps.createInstallationAccessToken(installationID:options:)`, `InstallationAuthenticator`",
    "apps/revoke-installation-access-token": "`apps.revokeInstallationAccessToken()`",
    "apps/delete-installation": "`apps.deleteInstallation(id:)`",
    "apps/suspend-installation": "`apps.suspendInstallation(id:)`",
    "apps/unsuspend-installation": "`apps.unsuspendInstallation(id:)`",
    "apps/list-installations-for-authenticated-user": "`apps.installationsForAuthenticatedUser()`",
    # Authentication: OAuth app token management
    "apps/check-token": "`oauthApplication(clientID:clientSecret:).checkToken(_:)`",
    "apps/reset-token": "`oauthApplication(…).resetToken(_:)`",
    "apps/delete-token": "`oauthApplication(…).deleteToken(_:)`",
    "apps/delete-authorization": "`oauthApplication(…).deleteGrant(_:)`",
    # Projects
    "projects/list-for-org": "`projects(.organization(_)).list(matching:perPage:)`",
    "projects/list-for-user": "`projects(.user(_)).list(matching:perPage:)`",
    "projects/get-for-org": "`projects(.organization(_)).project(_:)`",
    "projects/get-for-user": "`projects(.user(_)).project(_:)`",
    "projects/list-fields-for-org": "`fields(of:)`, `field(named:of:)`",
    "projects/list-fields-for-user": "`fields(of:)`, `field(named:of:)`",
    "projects/get-field-for-org": "`field(_:of:)`",
    "projects/get-field-for-user": "`field(_:of:)`",
    "projects/add-field-for-org": "`addField(_:to:)`",
    "projects/add-field-for-user": "`addField(_:to:)`",
    "projects/list-items-for-org": "`items(of:matching:fields:perPage:)`",
    "projects/list-items-for-user": "`items(of:matching:fields:perPage:)`",
    "projects/get-org-item": "`item(_:of:fields:)`",
    "projects/get-user-item": "`item(_:of:fields:)`",
    "projects/add-item-for-org": "`addItem(_:to:)`",
    "projects/add-item-for-user": "`addItem(_:to:)`",
    "projects/update-item-for-org": "`updateItem(_:in:_:)`",
    "projects/update-item-for-user": "`updateItem(_:in:_:)`",
    "projects/delete-item-for-org": "`deleteItem(_:from:)`",
    "projects/delete-item-for-user": "`deleteItem(_:from:)`",
    "projects/create-draft-item-for-org": "`addDraftIssue(title:body:to:)`",
    "projects/create-draft-item-for-authenticated-user": "`addDraftIssue(title:body:to:)`",
    "projects/create-view-for-org": "`createView(_:in:)`",
    "projects/create-view-for-user": "`createView(_:in:)`",
    "projects/list-view-items-for-org": "`items(inView:of:fields:perPage:)`",
    "projects/list-view-items-for-user": "`items(inView:of:fields:perPage:)`",
}

# operationId -> note
IN_PROGRESS: dict[str, str] = {}

# operationId -> note, for to-do endpoints scheduled outside their category's milestone
DEFERRED: dict[str, str] = {
    # Artifact attestations are supply-chain security, so they ship with the security work.
    "users/list-attestations": "milestone 5",
    "users/list-attestations-bulk": "milestone 5",
    "users/delete-attestations-bulk": "milestone 5",
    "users/delete-attestations-by-subject-digest": "milestone 5",
    "users/delete-attestations-by-id": "milestone 5",
    # Org attestations and artifact metadata are supply-chain security.
    "orgs/list-attestations-bulk": "milestone 5",
    "orgs/delete-attestations-bulk": "milestone 5",
    "orgs/delete-attestations-by-subject-digest": "milestone 5",
    "orgs/list-attestation-repositories": "milestone 5",
    "orgs/delete-attestations-by-id": "milestone 5",
    "orgs/list-attestations": "milestone 5",
    "orgs/create-artifact-deployment-record": "milestone 5",
    "orgs/set-cluster-deployment-records": "milestone 5",
    "orgs/create-cluster-deployment-records-job": "milestone 5",
    "orgs/get-cluster-deployment-records-job": "milestone 5",
    "orgs/create-artifact-storage-record": "milestone 5",
    "orgs/list-artifact-deployment-records": "milestone 5",
    "orgs/list-artifact-storage-records": "milestone 5",
    # Ruleset history returns full rulesets, so it ships with the repository rulesets work.
    "orgs/get-org-ruleset-history": "the rulesets work",
    "orgs/get-org-ruleset-version": "the rulesets work",
    # Org issue fields and types ship with issues.
    "repos/list-issue-types": "milestone 3",
    "orgs/list-issue-fields": "milestone 3",
    "orgs/create-issue-field": "milestone 3",
    "orgs/update-issue-field": "milestone 3",
    "orgs/delete-issue-field": "milestone 3",
    "orgs/list-issue-types": "milestone 3",
    "orgs/create-issue-type": "milestone 3",
    "orgs/update-issue-type": "milestone 3",
    "orgs/delete-issue-type": "milestone 3",
}

MILESTONES = [
    ("M1", "Authentication & Projects", "✅ Done"),
    ("M2", "Core resources: users, organizations, teams, repositories", "🚧 In progress"),
    ("M3", "Collaboration: issues, pull requests, search, activity", "⬜ Planned"),
    ("M4", "Automation: Actions, checks, packages, app webhooks", "⬜ Planned"),
    ("M5", "Security: code scanning, secret scanning, Dependabot", "⬜ Planned"),
    ("M6", "Platform & admin: Copilot, Codespaces, billing, migrations", "⬜ Planned"),
]

CATEGORY_MILESTONE = {
    "projects": "M1", "rate-limit": "M1",
    "users": "M2", "orgs": "M2", "teams": "M2", "repos": "M2", "git": "M2", "meta": "M2",
    "emojis": "M2", "licenses": "M2", "gitignore": "M2", "codes-of-conduct": "M2", "markdown": "M2",
    "issues": "M3", "pulls": "M3", "reactions": "M3", "search": "M3", "activity": "M3", "gists": "M3",
    "actions": "M4", "checks": "M4", "packages": "M4", "apps": "M4", "oidc": "M4",
    "hosted-compute": "M4", "private-registries": "M4", "agent-tasks": "M4", "agent-automations": "M4",
    "agent-merge": "M4", "agents": "M4",
    "code-scanning": "M5", "secret-scanning": "M5", "dependabot": "M5", "dependency-graph": "M5",
    "security-advisories": "M5", "code-security": "M5", "code-quality": "M5", "credentials": "M5",
    "campaigns": "M5",
}

METHODS = ("get", "post", "put", "patch", "delete")


def main(spec_path: str) -> None:
    with open(spec_path) as f:
        spec = json.load(f)

    by_category: dict[str, list[dict]] = defaultdict(list)
    for path, item in spec["paths"].items():
        for method in METHODS:
            op = item.get(method)
            if not op:
                continue
            category = (op.get("tags") or ["other"])[0]
            by_category[category].append({
                "method": method.upper(),
                "path": path,
                "id": op["operationId"],
                "summary": op.get("summary", "").strip(),
                "deprecated": op.get("deprecated", False),
            })

    total = sum(len(v) for v in by_category.values())
    done = sum(1 for v in by_category.values() for e in v if e["id"] in DONE)
    out = []
    w = out.append

    w("# GHKit API coverage\n")
    w(f"Tracks every GitHub REST endpoint, plus the GraphQL-only features GHKit wraps. "
      f"Generated from GitHub's [OpenAPI description](https://github.com/github/rest-api-description) "
      f"(version {spec['info']['version']}) on {date.today().isoformat()} by `Scripts/generate_todo.py`.\n")
    w("**Legend:** ✅ done · 🚧 in progress · ⬜ to do · ~~struck~~ deprecated by GitHub\n")
    w(f"**REST progress:** {done} of {total} endpoints ({done * 100 // total}%)\n")

    w("## Milestones\n")
    w("| Milestone | Scope | Status |")
    w("|---|---|---|")
    for key, name, status in MILESTONES:
        w(f"| {key} | {name} | {status} |")
    w("")

    w(MILESTONE_ONE_DETAILS)

    w("## Categories\n")
    w("| Category | Milestone | Done | Total | Status |")
    w("|---|---|---:|---:|---|")
    for category in sorted(by_category, key=lambda c: (CATEGORY_MILESTONE.get(c, "M6"), c)):
        endpoints = by_category[category]
        n_done = sum(1 for e in endpoints if e["id"] in DONE)
        n_prog = sum(1 for e in endpoints if e["id"] in IN_PROGRESS)
        status = "✅" if n_done == len(endpoints) else ("🚧" if n_done or n_prog else "⬜")
        milestone = CATEGORY_MILESTONE.get(category, "M6")
        if category == "apps":
            milestone = "M1 (auth) · M4 (rest)"
        w(f"| [{category}](#{category}) | {milestone} | {n_done} | {len(endpoints)} | {status} |")
    w("")

    w(GRAPHQL_SECTION)
    w(OAUTH_SECTION)
    w(LIBRARY_SECTION)

    w("## REST endpoints\n")
    for category in sorted(by_category, key=lambda c: (CATEGORY_MILESTONE.get(c, "M6"), c)):
        endpoints = sorted(by_category[category], key=lambda e: (e["path"], METHODS.index(e["method"].lower())))
        n_done = sum(1 for e in endpoints if e["id"] in DONE)
        w(f"### {category}\n")
        w(f"{n_done}/{len(endpoints)} done · milestone {CATEGORY_MILESTONE.get(category, 'M6')}\n")
        for e in endpoints:
            line = f"`{e['method']} {e['path']}` — {e['summary']}"
            if e["deprecated"]:
                line = f"~~{line}~~"
            if e["id"] in DONE:
                w(f"- [x] ✅ {line} → {DONE[e['id']]}")
            elif e["id"] in IN_PROGRESS:
                w(f"- [ ] 🚧 {line} ({IN_PROGRESS[e['id']]})")
            elif e["id"] in DEFERRED:
                w(f"- [ ] {line} (deferred to {DEFERRED[e['id']]})")
            else:
                w(f"- [ ] {line}")
        w("")

    sys.stdout.write("\n".join(out))


MILESTONE_ONE_DETAILS = """### Milestone 1: Authentication & Projects ✅

**Authentication**
- [x] Personal access tokens, fine-grained and classic (`TokenAuthenticator`, `GitHubClient(token:)`)
- [x] OAuth device flow, with interval and `slow_down` handling (`DeviceFlow`)
- [x] OAuth web flow with PKCE and state checking (`OAuthWebFlow`), plus `ASWebAuthenticationSession` support in GHKitUI
- [x] Expiring user tokens, refreshed automatically with one shared refresh (`OAuthAuthenticator`)
- [x] GitHub App JWTs, RS256 signed with PKCS#1 or PKCS#8 keys (`GitHubAppAuthenticator`)
- [x] Installation tokens, minted and cached (`InstallationAuthenticator`)
- [x] OAuth app token check, reset, revoke, and grant deletion (`OAuthApplicationAPI`, Basic auth)
- [x] Credential storage in the Keychain or in memory (`KeychainCredentialStore`, `InMemoryCredentialStore`)
- [x] Token scope and expiry reporting (`verifyAuthentication()`)
- [x] SwiftUI: `GitHubSession` (`@Observable`), `GitHubSignInView`, `DeviceCodeView`, `\\.gitHubClient` environment value
- [ ] Scoped user tokens for GitHub Apps (`POST /applications/{client_id}/token/scoped`), moved to M4

**Projects (v2), for organizations and users**
- [x] List, get, filter projects
- [x] Fields: list, get, find by name, add (text, number, date, single select, iteration, issue field)
- [x] Items: list (with filters and field values), get, add issue or PR (by ID or by repo and number), add draft, update field values, delete
- [x] Views: create; list items in a view
- [x] GraphQL-backed: create, update, close, reopen, delete, copy, template on and off
- [x] GraphQL-backed: link to and unlink from repositories and teams; collaborators
- [x] GraphQL-backed: status updates (list, create, update, delete)
- [x] GraphQL-backed: archive, unarchive, reorder items; convert draft to issue; edit drafts
- [x] GraphQL-backed: rename fields, replace options or iterations, delete fields
- [ ] Project workflows (GraphQL `deleteProjectV2Workflow`, read-only workflow queries)
- [ ] View updates and deletion (not in the REST or GraphQL APIs yet)

Classic Projects (v1) aren't covered: GitHub removed them from the REST API.
"""

GRAPHQL_SECTION = """## GraphQL-only features

GitHub offers these only through GraphQL. GHKit wraps them behind the same `ProjectsAPI` methods.

| Mutation | Status | Swift API |
|---|---|---|
| `createProjectV2` | ✅ | `create(title:repositoryNodeID:teamNodeID:)` |
| `updateProjectV2` | ✅ | `update(_:title:shortDescription:readme:isPublic:)`, `close(_:)`, `reopen(_:)` |
| `deleteProjectV2` | ✅ | `delete(_:)` |
| `copyProjectV2` | ✅ | `copy(_:title:to:includeDraftIssues:)` |
| `markProjectV2AsTemplate` / `unmarkProjectV2AsTemplate` | ✅ | `markAsTemplate(_:)`, `unmarkAsTemplate(_:)` |
| `linkProjectV2ToRepository` / `unlinkProjectV2FromRepository` | ✅ | `link(_:toRepository:)`, `unlink(_:fromRepository:)` |
| `linkProjectV2ToTeam` / `unlinkProjectV2FromTeam` | ✅ | `link(_:toTeam:)`, `unlink(_:fromTeam:)` |
| `updateProjectV2Collaborators` | ✅ | `updateCollaborators(of:_:)` |
| `createProjectV2StatusUpdate` / `update…` / `delete…` | ✅ | `createStatusUpdate(in:…)`, `updateStatusUpdate(_:…)`, `deleteStatusUpdate(_:)` |
| `ProjectV2.statusUpdates` (query) | ✅ | `statusUpdates(of:limit:)` |
| `archiveProjectV2Item` / `unarchiveProjectV2Item` | ✅ | `archive(_:in:)`, `unarchive(_:in:)` |
| `updateProjectV2ItemPosition` | ✅ | `move(_:after:in:)` |
| `convertProjectV2DraftIssueItemToIssue` | ✅ | `convertDraftToIssue(_:in:repositoryNodeID:)` |
| `updateProjectV2DraftIssue` | ✅ | `updateDraftIssue(_:title:body:assigneeNodeIDs:)` |
| `updateProjectV2Field` / `deleteProjectV2Field` | ✅ | `updateField(_:name:options:iterations:)`, `deleteField(_:)` |
| `deleteProjectV2Workflow` | ⬜ | |
| Any other query or mutation | ✅ | `github.graphQL(_:variables:as:)` |
"""

OAUTH_SECTION = """## OAuth endpoints (github.com, outside the REST API)

| Endpoint | Status | Swift API |
|---|---|---|
| `GET /login/oauth/authorize` | ✅ | `OAuthWebFlow.makeAuthorizationRequest(login:allowSignup:)` |
| `POST /login/oauth/access_token` (code) | ✅ | `OAuthWebFlow.exchange(callbackURL:for:)`, `exchange(code:codeVerifier:)` |
| `POST /login/oauth/access_token` (refresh) | ✅ | `OAuthAuthenticator.refresh()`, `OAuthWebFlow.refresh(_:)` |
| `POST /login/device/code` | ✅ | `DeviceFlow.start()` |
| `POST /login/oauth/access_token` (device) | ✅ | `DeviceFlow.waitForAuthorization(_:)` |
"""

LIBRARY_SECTION = """## Library features

- [x] `async`/`await` everywhere, with typed throws (`throws(GitHubError)`)
- [x] `Sendable` value-type client; decoding runs off the caller's actor (`@concurrent`)
- [x] Lazy `AsyncSequence` pagination following `Link` headers (page and cursor styles), plus manual `page(_:at:)`
- [x] Rate limit parsing; automatic retry for secondary limits and server errors (`RetryPolicy`)
- [x] One automatic credential refresh and retry after a `401`
- [x] GitHub Enterprise Server and GHE.com data residency (`GitHubServer`)
- [x] Escape hatches: `GitHubRequest` for any REST endpoint, `graphQL(_:variables:as:)` for any query
- [x] Response hook for logging and rate-limit UI (`GitHubConfiguration.onResponse`)
- [ ] Conditional requests with ETag caching (`304 Not Modified` is already surfaced as `.notModified`)
- [ ] Webhook signature verification and payload models
- [ ] Typed GraphQL schema coverage beyond Projects
- [ ] Linux support (needs a swift-crypto fallback for PKCE and JWT signing)
- [ ] DocC catalog and a sample SwiftUI app
"""

if __name__ == "__main__":
    main(sys.argv[1])
