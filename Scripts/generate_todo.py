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
    "repos/list-deployments": "`repositories.deployments(_:_:sha:ref:task:environment:)`",
    "repos/get-deployment": "`repositories.deployment(id:in:_:)`",
    "repos/create-deployment": "`repositories.createDeployment(_:in:_:)`",
    "repos/delete-deployment": "`repositories.deleteDeployment(id:in:_:)`",
    "repos/list-deployment-statuses": "`repositories.deploymentStatuses(of:in:_:)`",
    "repos/get-deployment-status": "`repositories.deploymentStatus(id:of:in:_:)`",
    "repos/create-deployment-status": "`repositories.createDeploymentStatus(_:on:in:_:)`",
    "repos/get-all-environments": "`repositories.environments(_:_:)`",
    "repos/get-environment": "`repositories.environment(_:in:_:)`",
    "repos/create-or-update-environment": "`repositories.setEnvironment(_:in:_:_:)`",
    "repos/delete-an-environment": "`repositories.deleteEnvironment(_:in:_:)`",
    "repos/list-deployment-branch-policies": "`repositories.deploymentBranchPatterns(for:in:_:)`",
    "repos/get-deployment-branch-policy": "`repositories.deploymentBranchPattern(id:for:in:_:)`",
    "repos/create-deployment-branch-policy": "`repositories.addDeploymentBranchPattern(_:type:to:in:_:)`",
    "repos/update-deployment-branch-policy": "`repositories.updateDeploymentBranchPattern(id:to:for:in:_:)`",
    "repos/delete-deployment-branch-policy": "`repositories.deleteDeploymentBranchPattern(id:for:in:_:)`",
    "repos/get-all-deployment-protection-rules": "`repositories.deploymentProtectionRules(for:in:_:)`",
    "repos/get-custom-deployment-protection-rule": "`repositories.deploymentProtectionRule(id:for:in:_:)`",
    "repos/list-custom-deployment-rule-integrations": "`repositories.availableProtectionRuleApps(for:in:_:)`",
    "repos/create-deployment-protection-rule": "`repositories.enableProtectionRule(appID:for:in:_:)`",
    "repos/disable-deployment-protection-rule": "`repositories.disableProtectionRule(id:for:in:_:)`",
    "repos/list-webhooks": "`repositories.webhooks(_:_:)`",
    "repos/create-webhook": "`repositories.createWebhook(_:in:_:)`",
    "repos/get-webhook": "`repositories.webhook(id:in:_:)`",
    "repos/update-webhook": "`repositories.updateWebhook(id:in:_:_:)`",
    "repos/delete-webhook": "`repositories.deleteWebhook(id:in:_:)`",
    "repos/get-webhook-config-for-repo": "`repositories.webhookConfiguration(id:in:_:)`",
    "repos/update-webhook-config-for-repo": "`repositories.updateWebhookConfiguration(id:in:_:_:)`",
    "repos/list-webhook-deliveries": "`repositories.webhookDeliveries(id:in:_:status:)`",
    "repos/get-webhook-delivery": "`repositories.webhookDelivery(_:webhook:in:_:)`",
    "repos/redeliver-webhook-delivery": "`repositories.redeliver(_:webhook:in:_:)`",
    "repos/ping-webhook": "`repositories.pingWebhook(id:in:_:)`",
    "repos/test-push-webhook": "`repositories.testWebhook(id:in:_:)`",
    "repos/get-pages": "`repositories.pagesSite(_:_:)`",
    "repos/create-pages-site": "`repositories.createPagesSite(from:in:_:)`",
    "repos/update-information-about-pages-site": "`repositories.updatePagesSite(_:_:_:)`",
    "repos/delete-pages-site": "`repositories.deletePagesSite(_:_:)`",
    "repos/list-pages-builds": "`repositories.pagesBuilds(_:_:)`",
    "repos/request-pages-build": "`repositories.requestPagesBuild(_:_:)`",
    "repos/get-latest-pages-build": "`repositories.latestPagesBuild(_:_:)`",
    "repos/get-pages-build": "`repositories.pagesBuild(id:in:_:)`",
    "repos/create-pages-deployment": "`repositories.createPagesDeployment(_:in:_:)`",
    "repos/get-pages-deployment": "`repositories.pagesDeploymentState(id:in:_:)`",
    "repos/cancel-pages-deployment": "`repositories.cancelPagesDeployment(id:in:_:)`",
    "repos/get-pages-health-check": "`repositories.pagesHealthCheck(_:_:)`",
    "repos/get-code-frequency-stats": "`repositories.codeFrequency(_:_:)`",
    "repos/get-commit-activity-stats": "`repositories.commitActivity(_:_:)`",
    "repos/get-contributors-stats": "`repositories.contributorStatistics(_:_:)`",
    "repos/get-participation-stats": "`repositories.participation(_:_:)`",
    "repos/get-punch-card-stats": "`repositories.punchCard(_:_:)`",
    "repos/get-clones": "`repositories.clones(_:_:per:)`",
    "repos/get-top-paths": "`repositories.popularContent(_:_:)`",
    "repos/get-top-referrers": "`repositories.referrers(_:_:)`",
    "repos/get-views": "`repositories.views(_:_:per:)`",
    "repos/check-vulnerability-alerts": "`repositories.vulnerabilityAlertsEnabled(_:_:)`",
    "repos/enable-vulnerability-alerts": "`repositories.setVulnerabilityAlerts(enabled:in:_:)`",
    "repos/disable-vulnerability-alerts": "`repositories.setVulnerabilityAlerts(enabled:in:_:)`",
    "repos/check-automated-security-fixes": "`repositories.dependabotSecurityUpdates(_:_:)`",
    "repos/enable-automated-security-fixes": "`repositories.setDependabotSecurityUpdates(enabled:in:_:)`",
    "repos/disable-automated-security-fixes": "`repositories.setDependabotSecurityUpdates(enabled:in:_:)`",
    "repos/check-private-vulnerability-reporting": "`repositories.privateVulnerabilityReportingEnabled(_:_:)`",
    "repos/enable-private-vulnerability-reporting": "`repositories.setPrivateVulnerabilityReporting(enabled:in:_:)`",
    "repos/disable-private-vulnerability-reporting": "`repositories.setPrivateVulnerabilityReporting(enabled:in:_:)`",
    "repos/check-immutable-releases": "`repositories.immutableReleases(_:_:)`",
    "repos/enable-immutable-releases": "`repositories.setImmutableReleases(enabled:in:_:)`",
    "repos/disable-immutable-releases": "`repositories.setImmutableReleases(enabled:in:_:)`",
    "repos/custom-properties-for-repos-get-repository-values": "`repositories.customPropertyValues(_:_:)`",
    "repos/custom-properties-for-repos-create-or-update-repository-values": "`repositories.setCustomPropertyValues(_:in:_:)`",
    "repos/create-dispatch-event": "`repositories.dispatch(_:payload:to:_:)`",
    "repos/list-commits": "`repositories.commits(_:_:ref:path:author:committer:since:until:)`",
    "repos/get-commit": "`repositories.commit(_:in:_:)` / `commitDiff(_:in:_:format:)` / `commitSHA(for:in:_:)`",
    "repos/compare-commits": "`repositories.compare(_:_:in:_:)` / `compareDiff(_:_:in:_:format:)`",
    "repos/list-commit-comments-for-repo": "`repositories.commitComments(_:_:)`",
    "repos/list-comments-for-commit": "`repositories.comments(onCommit:in:_:)`",
    "repos/get-commit-comment": "`repositories.commitComment(id:in:_:)`",
    "repos/create-commit-comment": "`repositories.createCommitComment(_:on:in:_:path:position:)`",
    "repos/update-commit-comment": "`repositories.updateCommitComment(id:in:_:body:)`",
    "repos/delete-commit-comment": "`repositories.deleteCommitComment(id:in:_:)`",
    "repos/list-commit-statuses-for-ref": "`repositories.statuses(for:in:_:)`",
    "repos/get-combined-status-for-ref": "`repositories.combinedStatus(for:in:_:)`",
    "repos/create-commit-status": "`repositories.createStatus(_:on:in:_:)`",
    "repos/list-releases": "`repositories.releases(_:_:)`",
    "repos/get-release": "`repositories.release(id:in:_:)`",
    "repos/get-latest-release": "`repositories.latestRelease(_:_:)`",
    "repos/get-release-by-tag": "`repositories.release(tag:in:_:)`",
    "repos/create-release": "`repositories.createRelease(_:in:_:)`",
    "repos/update-release": "`repositories.updateRelease(id:in:_:_:)`",
    "repos/delete-release": "`repositories.deleteRelease(id:in:_:)`",
    "repos/generate-release-notes": "`repositories.generateReleaseNotes(for:in:_:target:previousTag:configurationFile:)`",
    "repos/list-release-assets": "`repositories.releaseAssets(of:in:_:)`",
    "repos/get-release-asset": "`repositories.releaseAsset(id:in:_:)` / `repositories.downloadReleaseAsset(id:in:_:)`",
    "repos/update-release-asset": "`repositories.updateReleaseAsset(id:in:_:fileName:label:)`",
    "repos/delete-release-asset": "`repositories.deleteReleaseAsset(id:in:_:)`",
    "repos/upload-release-asset": "`repositories.uploadReleaseAsset(_:fileName:label:contentType:to:)`",
    "repos/get-org-rulesets": "`rulesets(_:).list(targets:includesParents:)`",
    "repos/create-org-ruleset": "`rulesets(_:).create(_:)`",
    "repos/get-org-ruleset": "`rulesets(_:).ruleset(id:includesParents:)`",
    "repos/update-org-ruleset": "`rulesets(_:).update(id:_:)`",
    "repos/delete-org-ruleset": "`rulesets(_:).delete(id:)`",
    "repos/get-org-rule-suites": "`rulesets(_:).ruleSuites(ref:repository:period:actor:result:evaluateStatus:)`",
    "repos/get-org-rule-suite": "`rulesets(_:).ruleSuite(id:includeMetadata:)`",
    "repos/get-repo-rulesets": "`rulesets(_:).list(targets:includesParents:)`",
    "repos/create-repo-ruleset": "`rulesets(_:).create(_:)`",
    "repos/get-repo-ruleset": "`rulesets(_:).ruleset(id:includesParents:)`",
    "repos/update-repo-ruleset": "`rulesets(_:).update(id:_:)`",
    "repos/delete-repo-ruleset": "`rulesets(_:).delete(id:)`",
    "repos/get-repo-rule-suites": "`rulesets(_:).ruleSuites(ref:repository:period:actor:result:evaluateStatus:)`",
    "repos/get-repo-rule-suite": "`rulesets(_:).ruleSuite(id:includeMetadata:)`",
    "orgs/get-org-ruleset-history": "`rulesets(_:).history(of:)`",
    "repos/get-repo-ruleset-history": "`rulesets(_:).history(of:)`",
    "orgs/get-org-ruleset-version": "`rulesets(_:).version(_:of:)`",
    "repos/get-repo-ruleset-version": "`rulesets(_:).version(_:of:)`",
    "repos/get-branch-rules": "`repositories.rules(for:in:_:)`",
    "repos/list-branches": "`repositories.branches(_:_:protected:)`",
    "repos/get-branch": "`repositories.branch(_:in:_:)`",
    "repos/rename-branch": "`repositories.renameBranch(_:to:in:_:)`",
    "repos/list-branches-for-head-commit": "`repositories.branches(withHead:in:_:)`",
    "repos/merge": "`repositories.merge(_:into:in:_:message:)`",
    "repos/get-branch-protection": "`repositories.protection(of:in:_:)`",
    "repos/update-branch-protection": "`repositories.protect(_:in:_:rules:)`",
    "repos/delete-branch-protection": "`repositories.removeProtection(from:in:_:)`",
    "repos/get-admin-branch-protection": "`repositories.adminEnforcement(of:in:_:)`",
    "repos/set-admin-branch-protection": "`repositories.setAdminEnforcement(_:on:in:_:)`",
    "repos/delete-admin-branch-protection": "`repositories.setAdminEnforcement(_:on:in:_:)`",
    "repos/get-commit-signature-protection": "`repositories.signatureRequirement(of:in:_:)`",
    "repos/create-commit-signature-protection": "`repositories.setSignatureRequirement(_:on:in:_:)`",
    "repos/delete-commit-signature-protection": "`repositories.setSignatureRequirement(_:on:in:_:)`",
    "repos/get-pull-request-review-protection": "`repositories.reviewProtection(of:in:_:)`",
    "repos/update-pull-request-review-protection": "`repositories.updateReviewProtection(_:on:in:_:)`",
    "repos/delete-pull-request-review-protection": "`repositories.removeReviewProtection(from:in:_:)`",
    "repos/get-status-checks-protection": "`repositories.statusChecks(of:in:_:)`",
    "repos/update-status-check-protection": "`repositories.updateStatusChecks(on:in:_:strict:checks:)`",
    "repos/remove-status-check-protection": "`repositories.removeStatusChecks(from:in:_:)`",
    "repos/get-all-status-check-contexts": "`repositories.statusCheckContexts(of:in:_:)`",
    "repos/add-status-check-contexts": "`repositories.addStatusCheckContexts(_:to:in:_:)`",
    "repos/set-status-check-contexts": "`repositories.setStatusCheckContexts(_:on:in:_:)`",
    "repos/remove-status-check-contexts": "`repositories.removeStatusCheckContexts(_:from:in:_:)`",
    "repos/get-access-restrictions": "`repositories.pushRestrictions(of:in:_:)`",
    "repos/delete-access-restrictions": "`repositories.removePushRestrictions(from:in:_:)`",
    "repos/get-users-with-access-to-protected-branch": "`repositories.usersWithPushAccess(to:in:_:)`",
    "repos/add-user-access-restrictions": "`repositories.addPushAccess(users:to:in:_:)`",
    "repos/set-user-access-restrictions": "`repositories.setPushAccess(users:on:in:_:)`",
    "repos/remove-user-access-restrictions": "`repositories.removePushAccess(users:from:in:_:)`",
    "repos/get-teams-with-access-to-protected-branch": "`repositories.teamsWithPushAccess(to:in:_:)`",
    "repos/add-team-access-restrictions": "`repositories.addPushAccess(teams:to:in:_:)`",
    "repos/set-team-access-restrictions": "`repositories.setPushAccess(teams:on:in:_:)`",
    "repos/remove-team-access-restrictions": "`repositories.removePushAccess(teams:from:in:_:)`",
    "repos/get-apps-with-access-to-protected-branch": "`repositories.appsWithPushAccess(to:in:_:)`",
    "repos/add-app-access-restrictions": "`repositories.addPushAccess(apps:to:in:_:)`",
    "repos/set-app-access-restrictions": "`repositories.setPushAccess(apps:on:in:_:)`",
    "repos/remove-app-access-restrictions": "`repositories.removePushAccess(apps:from:in:_:)`",
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
    # Issues (milestone 3)
    "issues/list": "`issues.list(_:in:matching:sort:ascending:perPage:)` with `.everywhere`",
    "issues/list-for-authenticated-user": "`issues.list(_:in:matching:sort:ascending:perPage:)` with `.personalRepositories`",
    "issues/list-for-org": "`issues.list(_:in:matching:sort:ascending:perPage:)` with `.organization(_:)`",
    "issues/list-for-repo": "`issues.list(_:_:matching:sort:ascending:perPage:)`",
    "issues/get": "`issues.issue(_:in:_:)`",
    "issues/create": "`issues.create(_:in:_:)`",
    "issues/update": "`issues.update(_:in:_:_:)`, `close(_:in:_:reason:)`, `reopen(_:in:_:)`",
    "issues/lock": "`issues.lock(_:in:_:reason:)`",
    "issues/unlock": "`issues.unlock(_:in:_:)`",
    "issues/list-assignees": "`issues.assignees(_:_:perPage:)`",
    "issues/check-user-can-be-assigned": "`issues.canAssign(_:in:_:)`",
    "issues/check-user-can-be-assigned-to-issue": "`issues.canAssign(_:to:in:_:)`",
    "issues/add-assignees": "`issues.addAssignees(_:to:in:_:)`",
    "issues/remove-assignees": "`issues.removeAssignees(_:from:in:_:)`",
    "issues/list-comments": "`issues.comments(on:in:_:updatedSince:perPage:)`",
    "issues/list-comments-for-repo": "`issues.comments(_:_:sort:ascending:updatedSince:perPage:)`",
    "issues/get-comment": "`issues.comment(id:in:_:)`",
    "issues/create-comment": "`issues.createComment(_:on:in:_:)`",
    "issues/update-comment": "`issues.updateComment(id:in:_:body:)`",
    "issues/delete-comment": "`issues.deleteComment(id:in:_:)`",
    "issues/pin-comment": "`issues.pinComment(id:in:_:)`",
    "issues/unpin-comment": "`issues.unpinComment(id:in:_:)`",
    "issues/list-labels-for-repo": "`issues.labels(_:_:perPage:)`",
    "issues/get-label": "`issues.label(named:in:_:)`",
    "issues/create-label": "`issues.createLabel(_:in:_:)`",
    "issues/update-label": "`issues.updateLabel(named:in:_:_:)`",
    "issues/delete-label": "`issues.deleteLabel(named:in:_:)`",
    "issues/list-labels-on-issue": "`issues.labels(on:in:_:perPage:)`",
    "issues/add-labels": "`issues.addLabels(_:to:in:_:)`",
    "issues/set-labels": "`issues.setLabels(_:on:in:_:)`",
    "issues/remove-label": "`issues.removeLabel(named:from:in:_:)`",
    "issues/remove-all-labels": "`issues.removeAllLabels(from:in:_:)`",
    "issues/list-labels-for-milestone": "`issues.labels(inMilestone:in:_:perPage:)`",
    "issues/list-milestones": "`issues.milestones(_:_:state:sort:ascending:perPage:)`",
    "issues/get-milestone": "`issues.milestone(_:in:_:)`",
    "issues/create-milestone": "`issues.createMilestone(_:in:_:)`",
    "issues/update-milestone": "`issues.updateMilestone(_:in:_:_:)`",
    "issues/delete-milestone": "`issues.deleteMilestone(_:in:_:)`",
    "issues/list-events-for-repo": "`issues.events(_:_:perPage:)`",
    "issues/get-event": "`issues.event(id:in:_:)`",
    "issues/list-events": "`issues.events(on:in:_:perPage:)`",
    "issues/get-parent": "`issues.parent(of:in:_:)`",
    "issues/list-sub-issues": "`issues.subIssues(of:in:_:perPage:)`",
    "issues/add-sub-issue": "`issues.addSubIssue(id:to:in:_:replaceParent:)`",
    "issues/remove-sub-issue": "`issues.removeSubIssue(id:from:in:_:)`",
    "issues/reprioritize-sub-issue": "`issues.moveSubIssue(id:_:of:in:_:)`",
    "issues/list-dependencies-blocked-by": "`issues.blockers(of:in:_:perPage:)`",
    "issues/list-dependencies-blocking": "`issues.blockedIssues(by:in:_:perPage:)`",
    "issues/add-blocked-by-dependency": "`issues.addBlocker(id:to:in:_:)`",
    "issues/remove-dependency-blocked-by": "`issues.removeBlocker(id:from:in:_:)`",
    "issues/list-relates-to": "`issues.relatedIssues(to:in:_:perPage:)`",
    "issues/add-relates-to": "`issues.addRelatedIssue(id:to:in:_:)`",
    "issues/remove-relates-to": "`issues.removeRelatedIssue(id:from:in:_:)`",
    "issues/list-issue-field-values-for-issue": "`issues.fieldValues(of:in:_:perPage:)`",
    "issues/add-issue-field-values": "`issues.addFieldValues(_:to:in:_:)`",
    "issues/set-issue-field-values": "`issues.setFieldValues(_:on:in:_:)`",
    "issues/delete-issue-field-value": "`issues.deleteFieldValue(fieldID:from:in:_:)`",
    "issues/list-suggestions": "`issues.suggestions(for:in:_:state:action:perPage:)`",
    "issues/approve-suggestion": "`issues.approveSuggestion(id:on:in:_:)`",
    "issues/dismiss-suggestion": "`issues.dismissSuggestion(id:on:in:_:)`",
    "issues/list-issue-artifacts": "`issues.artifacts(on:in:_:type:perPage:)`",
    "issues/get-issue-artifact": "`issues.artifact(_:on:in:_:)`",
    "issues/create-issue-artifact": "`issues.createArtifact(_:on:in:_:)`",
    "issues/update-issue-artifact": "`issues.updateArtifact(_:on:in:_:name:body:)`",
    "issues/delete-issue-artifact": "`issues.deleteArtifact(_:on:in:_:)`",
    "repos/list-issue-types": "`issues.types(_:_:)`",
    "orgs/list-issue-types": "`issues.types(in:)`",
    "orgs/create-issue-type": "`issues.createType(_:in:)`",
    "orgs/update-issue-type": "`issues.updateType(id:in:_:)`",
    "orgs/delete-issue-type": "`issues.deleteType(id:in:)`",
    "orgs/list-issue-fields": "`issues.fields(in:)`",
    "orgs/create-issue-field": "`issues.createField(_:in:)`",
    "orgs/update-issue-field": "`issues.updateField(id:in:_:)`",
    "orgs/delete-issue-field": "`issues.deleteField(id:in:)`",
    "issues/list-events-for-timeline": "`issues.timeline(of:in:_:excluding:perPage:)`",
    # Pull requests (milestone 3)
    "pulls/list": "`pullRequests.list(_:_:state:head:base:sort:ascending:perPage:)`",
    "pulls/get": "`pullRequests.pullRequest(_:in:_:)` / `diff(_:in:_:format:)`",
    "pulls/create": "`pullRequests.create(_:in:_:)`",
    "pulls/update": "`pullRequests.update(_:in:_:_:)`, `close(_:in:_:)`, `reopen(_:in:_:)`",
    "pulls/list-commits": "`pullRequests.commits(of:in:_:perPage:)`",
    "pulls/list-files": "`pullRequests.files(of:in:_:perPage:)`",
    "repos/list-pull-requests-associated-with-commit": "`pullRequests.pullRequests(containing:in:_:perPage:)`",
    "pulls/check-if-merged": "`pullRequests.isMerged(_:in:_:)`",
    "pulls/merge": "`pullRequests.merge(_:in:_:_:)`",
    "pulls/merge-async": "`pullRequests.mergeInBackground(_:in:_:_:action:bypassRules:)`",
    "pulls/get-merge-async-result": "`pullRequests.backgroundMerge(_:of:in:_:)`",
    "pulls/update-branch": "`pullRequests.updateBranch(_:in:_:expectedHeadSHA:)`",
    "pulls/list-requested-reviewers": "`pullRequests.requestedReviewers(of:in:_:)`",
    "pulls/request-reviewers": "`pullRequests.requestReviewers(_:teams:on:in:_:)`",
    "pulls/remove-requested-reviewers": "`pullRequests.removeRequestedReviewers(_:teams:from:in:_:)`",
    "pulls/rerequest-reviewers": "`pullRequests.rerequestReviewers(_:teams:on:in:_:)`",
    "pulls/list-reviews": "`pullRequests.reviews(of:in:_:perPage:)`",
    "pulls/get-review": "`pullRequests.review(id:of:in:_:)`",
    "pulls/create-review": "`pullRequests.createReview(_:on:in:_:)`",
    "pulls/submit-review": "`pullRequests.submitReview(id:of:in:_:event:body:)`",
    "pulls/update-review": "`pullRequests.updateReview(id:of:in:_:body:)`",
    "pulls/delete-pending-review": "`pullRequests.deletePendingReview(id:of:in:_:)`",
    "pulls/dismiss-review": "`pullRequests.dismissReview(id:of:in:_:message:)`",
    "pulls/list-comments-for-review": "`pullRequests.comments(inReview:of:in:_:perPage:)`",
    "pulls/list-review-comments": "`pullRequests.reviewComments(on:in:_:sort:ascending:updatedSince:perPage:)`",
    "pulls/list-review-comments-for-repo": "`pullRequests.reviewComments(_:_:sort:ascending:updatedSince:perPage:)`",
    "pulls/get-review-comment": "`pullRequests.reviewComment(id:in:_:)`",
    "pulls/create-review-comment": "`pullRequests.createReviewComment(_:on:in:_:)`",
    "pulls/create-reply-for-review-comment": "`pullRequests.replyToReviewComment(id:on:in:_:body:)`",
    "pulls/update-review-comment": "`pullRequests.updateReviewComment(id:in:_:body:)`",
    "pulls/delete-review-comment": "`pullRequests.deleteReviewComment(id:in:_:)`",
    "pull-request-stacks/list": "`pullRequests.stacks(_:_:containing:perPage:)`",
    "pull-request-stacks/get": "`pullRequests.stack(_:in:_:)`",
    "pull-request-stacks/create": "`pullRequests.createStack(_:in:_:)`",
    "pull-request-stacks/add": "`pullRequests.addToStack(_:stack:in:_:)`",
    "pull-request-stacks/unstack": "`pullRequests.unstack(_:in:_:)`",
    # Reactions (milestone 3)
    "reactions/list-for-commit-comment": "`reactions.list(on:in:_:content:perPage:)`",
    "reactions/create-for-commit-comment": "`reactions.add(_:to:in:_:)`",
    "reactions/delete-for-commit-comment": "`reactions.delete(id:from:in:_:)`",
    "reactions/list-for-issue-comment": "`reactions.list(on:in:_:content:perPage:)`",
    "reactions/create-for-issue-comment": "`reactions.add(_:to:in:_:)`",
    "reactions/delete-for-issue-comment": "`reactions.delete(id:from:in:_:)`",
    "reactions/list-for-issue": "`reactions.list(on:in:_:content:perPage:)`",
    "reactions/create-for-issue": "`reactions.add(_:to:in:_:)`",
    "reactions/delete-for-issue": "`reactions.delete(id:from:in:_:)`",
    "reactions/list-for-pull-request-review-comment": "`reactions.list(on:in:_:content:perPage:)`",
    "reactions/create-for-pull-request-review-comment": "`reactions.add(_:to:in:_:)`",
    "reactions/delete-for-pull-request-comment": "`reactions.delete(id:from:in:_:)`",
    "reactions/list-for-release": "`reactions.list(on:in:_:content:perPage:)`",
    "reactions/create-for-release": "`reactions.add(_:to:in:_:)`",
    "reactions/delete-for-release": "`reactions.delete(id:from:in:_:)`",
    # Search (milestone 3)
    "search/code": "`search.code(_:textMatches:perPage:)`",
    "search/commits": "`search.commits(_:sort:ascending:textMatches:perPage:)`",
    "search/issues-and-pull-requests": "`search.issues(_:sort:ascending:advanced:mode:textMatches:perPage:)`",
    "search/labels": "`search.labels(_:inRepository:sort:ascending:textMatches:perPage:)`",
    "search/repos": "`search.repositories(_:sort:ascending:textMatches:perPage:)`",
    "search/topics": "`search.topics(_:textMatches:perPage:)`",
    "search/users": "`search.users(_:sort:ascending:textMatches:perPage:)`",
    # Activity (milestone 3)
    "activity/list-public-events": "`activity.events(_:perPage:)`",
    "activity/get-feeds": "`activity.feeds()`",
    "activity/list-public-events-for-repo-network": "`activity.events(_:perPage:)`",
    "activity/list-notifications-for-authenticated-user": "`activity.notifications(matching:perPage:)`",
    "activity/mark-notifications-as-read": "`activity.markNotificationsRead(before:)`",
    "activity/get-thread": "`activity.thread(id:)`",
    "activity/mark-thread-as-read": "`activity.markThreadRead(id:)`",
    "activity/mark-thread-as-done": "`activity.markThreadDone(id:)`",
    "activity/get-thread-subscription-for-authenticated-user": "`activity.threadSubscription(id:)`",
    "activity/set-thread-subscription": "`activity.subscribeToThread(id:ignored:)`",
    "activity/delete-thread-subscription": "`activity.unsubscribeFromThread(id:)`",
    "activity/list-public-org-events": "`activity.events(_:perPage:)`",
    "activity/list-repo-events": "`activity.events(_:perPage:)`",
    "activity/list-repo-notifications-for-authenticated-user": "`activity.notifications(in:_:matching:perPage:)`",
    "activity/mark-repo-notifications-as-read": "`activity.markNotificationsRead(in:_:before:)`",
    "activity/list-stargazers-for-repo": "`activity.stargazers(of:_:perPage:)` and `activity.stars(on:_:perPage:)`",
    "activity/get-stargazer-count-for-repo": "`activity.stargazerCount(of:_:)`",
    "activity/get-stargazer-history-for-repo": "`activity.starHistory(of:_:perPage:)`",
    "activity/list-watchers-for-repo": "`activity.watchers(of:_:perPage:)`",
    "activity/get-repo-subscription": "`activity.subscription(to:_:)`",
    "activity/set-repo-subscription": "`activity.watch(_:_:ignored:)`",
    "activity/delete-repo-subscription": "`activity.unwatch(_:_:)`",
    "activity/list-repos-starred-by-authenticated-user": "`activity.starredRepositories(by:sort:ascending:perPage:)` and `activity.stars(by:sort:ascending:perPage:)`",
    "activity/check-repo-is-starred-by-authenticated-user": "`activity.isStarred(_:_:)`",
    "activity/star-repo-for-authenticated-user": "`activity.star(_:_:)`",
    "activity/unstar-repo-for-authenticated-user": "`activity.unstar(_:_:)`",
    "activity/list-watched-repos-for-authenticated-user": "`activity.watchedRepositories(by:perPage:)`",
    "activity/list-events-for-authenticated-user": "`activity.events(_:perPage:)`",
    "activity/list-org-events-for-authenticated-user": "`activity.events(_:perPage:)`",
    "activity/list-public-events-for-user": "`activity.events(_:perPage:)`",
    "activity/list-received-events-for-user": "`activity.events(_:perPage:)`",
    "activity/list-received-public-events-for-user": "`activity.events(_:perPage:)`",
    "activity/list-repos-starred-by-user": "`activity.starredRepositories(by:sort:ascending:perPage:)` and `activity.stars(by:sort:ascending:perPage:)`",
    "activity/list-repos-watched-by-user": "`activity.watchedRepositories(by:perPage:)`",
    # Gists (milestone 3)
    "gists/list": "`gists.list(_:since:perPage:)`",
    "gists/create": "`gists.create(_:)`",
    "gists/list-public": "`gists.list(_:since:perPage:)`",
    "gists/list-starred": "`gists.list(_:since:perPage:)`",
    "gists/get": "`gists.gist(id:revision:)`",
    "gists/update": "`gists.update(id:_:)`",
    "gists/delete": "`gists.delete(id:)`",
    "gists/list-comments": "`gists.comments(on:perPage:)`",
    "gists/create-comment": "`gists.createComment(_:on:)`",
    "gists/get-comment": "`gists.comment(id:on:)`",
    "gists/update-comment": "`gists.updateComment(id:on:body:)`",
    "gists/delete-comment": "`gists.deleteComment(id:on:)`",
    "gists/list-commits": "`gists.commits(of:perPage:)`",
    "gists/list-forks": "`gists.forks(of:perPage:)`",
    "gists/fork": "`gists.fork(id:)`",
    "gists/check-is-starred": "`gists.isStarred(id:)`",
    "gists/star": "`gists.star(id:)`",
    "gists/unstar": "`gists.unstar(id:)`",
    "gists/get-revision": "`gists.gist(id:revision:)`",
    "gists/list-for-user": "`gists.list(_:since:perPage:)`",
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
    "repos/create-attestation": "milestone 5",
    "repos/list-attestations": "milestone 5",
    "orgs/create-artifact-deployment-record": "milestone 5",
    "orgs/set-cluster-deployment-records": "milestone 5",
    "orgs/create-cluster-deployment-records-job": "milestone 5",
    "orgs/get-cluster-deployment-records-job": "milestone 5",
    "orgs/create-artifact-storage-record": "milestone 5",
    "orgs/list-artifact-deployment-records": "milestone 5",
    "orgs/list-artifact-storage-records": "milestone 5",
    # Ruleset history returns full rulesets, so it ships with the repository rulesets work.
}

MILESTONES = [
    ("M1", "Authentication & Projects", "✅ Done"),
    ("M2", "Core resources: users, organizations, teams, repositories", "🚧 In progress"),
    ("M3", "Collaboration: issues, pull requests, search, activity", "✅ Done"),
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
