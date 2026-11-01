#!/usr/bin/env bash
# Works out the next semantic version for the changes on HEAD that aren't on BASE yet.
#
#   .github/scripts/next_version.sh origin/main
#
# Rules:
#   breaking  = public API break (swift package diagnose-api-breaking-changes against
#               the last release tag), or a commit like `feat!:` / `BREAKING CHANGE:`
#   feature   = any `feat:` / `feat(scope):` commit
#   patch     = anything else
# Before 1.0.0, breaking changes bump the minor version (0.x semver convention).
# With no release tags yet, the first version is 0.1.0.
#
# Writes version, previous, level, and reason to $GITHUB_OUTPUT when set.
set -euo pipefail

base="${1:-origin/main}"

last_tag="$(git describe --tags --abbrev=0 --match '[0-9]*.[0-9]*.[0-9]*' "$base" 2>/dev/null || true)"
subjects="$(git log --format='%s' "$base..HEAD")"
bodies="$(git log --format='%b' "$base..HEAD")"

if [ -z "$subjects" ]; then
    echo "No changes between $base and HEAD." >&2
    exit 1
fi

level="patch"
reason="fixes and maintenance only"

if printf '%s\n' "$subjects" | grep -Eq '^feat(\([^)]*\))?:'; then
    level="minor"
    reason="new features (feat commits)"
fi
if printf '%s\n' "$subjects" | grep -Eq '^[a-z]+(\([^)]*\))?!:' || printf '%s\n' "$bodies" | grep -q 'BREAKING CHANGE'; then
    level="major"
    reason="breaking change marked in a commit"
fi
if [ -n "$last_tag" ] && [ "$level" != "major" ]; then
    if api_report="$(swift package diagnose-api-breaking-changes "$last_tag" --products GHKit GHKitUI 2>&1)"; then
        echo "No public API breaks against $last_tag." >&2
    elif printf '%s\n' "$api_report" | grep -q 'API breakage'; then
        printf '%s\n' "$api_report" >&2
        level="major"
        reason="public API break detected against $last_tag"
    else
        printf '%s\n' "$api_report" >&2
        echo "::warning::Couldn't check for API breaks against $last_tag; using commit messages only." >&2
    fi
fi

if [ -z "$last_tag" ]; then
    previous="none"
    version="0.1.0"
    reason="first release"
else
    previous="${last_tag#v}"
    IFS=. read -r major minor patch <<EOF
$previous
EOF
    if [ "$major" -eq 0 ] && [ "$level" = "major" ]; then
        level="minor (breaking, pre-1.0)"
        minor=$((minor + 1)); patch=0
    else
        case "$level" in
            major) major=$((major + 1)); minor=0; patch=0 ;;
            minor) minor=$((minor + 1)); patch=0 ;;
            *) patch=$((patch + 1)) ;;
        esac
    fi
    version="$major.$minor.$patch"
fi

echo "Next version: $version ($level: $reason; previous: $previous)" >&2
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "version=$version"
        echo "previous=$previous"
        echo "level=$level"
        echo "reason=$reason"
    } >> "$GITHUB_OUTPUT"
fi
echo "$version"
