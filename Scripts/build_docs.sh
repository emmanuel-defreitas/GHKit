#!/usr/bin/env bash
# Builds the GHKit and GHKitUI DocC documentation as one static website.
#
#   Scripts/build_docs.sh [output-dir]          # default: .build/docs/site
#
# Environment:
#   DOCS_BASE_PATH   URL path the site is served under. Default: GHKit (GitHub Pages).
#                    Set it to "" to serve from the root, e.g. for a local preview.
#   DOCS_SOURCE_REF  Git ref that "view source" links point at. Default: main.
#   GITHUB_REPOSITORY  owner/repo for source links. Default: emmanuel-defreitas/GHKit.
#
# Local preview:
#   DOCS_BASE_PATH= Scripts/build_docs.sh
#   python3 -m http.server --directory .build/docs/site 8000   # open http://localhost:8000
#
# Broken links and other DocC warnings fail the build. Incomplete parameter lists stay warnings.

set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")/.."
root="$PWD"
modules=(GHKit GHKitUI)
scratch=".build/docs"
work="$scratch/work"
output="${1:-$scratch/site}"
base_path="${DOCS_BASE_PATH-GHKit}"
source_ref="${DOCS_SOURCE_REF:-main}"
repository="${GITHUB_REPOSITORY:-emmanuel-defreitas/GHKit}"

docc() {
    if command -v xcrun >/dev/null; then xcrun docc "$@"; else command docc "$@"; fi
}

rm -rf "$work" "$output"
mkdir -p "$work"

echo "==> Extracting symbol graphs"
# SwiftPM in Xcode 26 also tries the test module, fails on it, and exits non-zero after writing
# the library graphs. Ignore the exit code and check for each module's graph instead.
log="$(swift package --scratch-path "$scratch" dump-symbol-graph \
    --minimum-access-level public --skip-synthesized-members 2>&1 | tee /dev/stderr || true)"
graphs="$(sed -n 's/^Files written to //p' <<<"$log" | tail -n 1)"
for module in "${modules[@]}"; do
    [ -f "$graphs/$module.symbols.json" ] || {
        echo "error: no symbol graph for $module in '$graphs'" >&2
        exit 1
    }
done

common=(
    --transform-for-static-hosting
    --source-service github
    --source-service-base-url "https://github.com/$repository/blob/$source_ref"
    --checkout-path "$root"
    --warnings-as-errors
    -Wwarning org.swift.docc.MissingParameterDocumentation
)
[ -n "$base_path" ] && common+=(--hosting-base-path "$base_path")

archives=()
for module in "${modules[@]}"; do
    echo "==> Converting $module"
    # Each module gets its own graphs, including extensions it adds to other modules (Module@Other).
    mkdir -p "$work/graphs/$module"
    cp "$graphs/$module.symbols.json" "$graphs/$module@"*.symbols.json "$work/graphs/$module/"

    extra=(--enable-experimental-external-link-support)
    # Let later modules link to the ones before them, e.g. GHKitUI to GHKit.
    for archive in ${archives[@]+"${archives[@]}"}; do extra+=(--dependency "$archive"); done

    docc convert "Sources/$module/$module.docc" \
        --additional-symbol-graph-dir "$work/graphs/$module" \
        --fallback-display-name "$module" \
        --fallback-bundle-identifier "com.github.${repository//\//.}.$module" \
        --output-path "$work/$module.doccarchive" \
        "${common[@]}" "${extra[@]}"
    archives+=("$work/$module.doccarchive")
done

echo "==> Merging into $output"
docc merge "${archives[@]}" \
    --synthesized-landing-page-name GHKit \
    --synthesized-landing-page-kind Package \
    --output-path "$work/combined.doccarchive"

mkdir -p "$(dirname "$output")"
mv "$work/combined.doccarchive" "$output"

# DocC has no page at the site root, so send visitors to the combined landing page.
cat >"$output/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>GHKit Documentation</title>
<meta http-equiv="refresh" content="0; url=documentation/">
<link rel="canonical" href="documentation/">
<a href="documentation/">GHKit Documentation</a>
HTML
echo "Documentation written to $output"
