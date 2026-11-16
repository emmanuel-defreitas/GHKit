#!/usr/bin/env bash
# Builds the GHKit, GHKitUI, and GHKitMCP DocC documentation as one static website.
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
modules=(GHKit GHKitUI GHKitMCP)
# GHKit re-exports these, and its reference documents all of them as one module.
umbrella_parts=(GHKitCore GHKitUsers GHKitRepositories GHKitIssues GHKitPullRequests GHKitOrganizations
    GHKitProjects GHKitActivity GHKitGists GHKitSearch GHKitApps GHKitMeta)
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
# Extension block symbols give GHKitUI's extensions of SwiftUI and GHKit types their own pages.
# They're on by default from Swift 6.4 but off in 6.2, so ask for them explicitly.
log="$(swift package --scratch-path "$scratch" dump-symbol-graph \
    --minimum-access-level public --skip-synthesized-members --emit-extension-block-symbols \
    2>&1 | tee /dev/stderr || true)"
graphs="$(sed -n 's/^Files written to //p' <<<"$log" | tail -n 1)"
for module in "${modules[@]}" "${umbrella_parts[@]}"; do
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
)
[ -n "$base_path" ] && common+=(--hosting-base-path "$base_path")

# Fails if DocC reported any warning other than an incomplete "- Parameters:" list.
# DocC 6.2 (Xcode 26) has no -Wwarning flag and no diagnostic IDs in this file, so match the message too.
check_diagnostics() {
    python3 -I - "$1" <<'PY'
import json, re, sys

allowed_id = "org.swift.docc.MissingParameterDocumentation"
allowed_summary = re.compile(r"^Parameter '.+' is missing documentation$")

diagnostics = json.load(open(sys.argv[1])).get("diagnostics", [])
failures = [
    d for d in diagnostics
    if d.get("severity") in ("warning", "error")
    and d.get("id") != allowed_id
    and not allowed_summary.match(d.get("summary", ""))
]
for d in failures:
    line = ((d.get("range") or {}).get("start") or {}).get("line", "?")
    print(f"error: {d.get('source', '')}:{line}: {d.get('summary')}", file=sys.stderr)
sys.exit(1 if failures else 0)
PY
}

# Builds GHKit's graphs from the modules it re-exports. Swift 6.4 already puts re-exported symbols in
# GHKit's own graph, but Swift 6.2 (CI) doesn't, and an incremental build can leave GHKit's graph stale.
# Symbols are merged by identifier. A module's extensions of another umbrella module's types, which
# Swift 6.2 writes as extension blocks in "Module@Other" graphs, become members of those types.
# Extensions of outside modules, such as Swift, go in "GHKit@Swift" graphs.
merge_umbrella_graphs() {
    python3 -I - "$graphs" "$1" "${umbrella_parts[@]}" <<'PY'
import json, os, sys

graphs, out, parts = sys.argv[1], sys.argv[2], sys.argv[3:]
ours = set(parts) | {"GHKit"}

def load(name):
    with open(os.path.join(graphs, name), encoding="utf-8") as f:
        return json.load(f)

def new_graph(template):
    graph = dict(template)
    graph["module"] = dict(template["module"], name="GHKit")
    graph["symbols"], graph["relationships"] = [], []
    return graph

main = None
external = {}
seen_symbols, seen_relationships = {}, {}

def add(graph, data):
    symbols = seen_symbols.setdefault(id(graph), set())
    relationships = seen_relationships.setdefault(id(graph), set())
    for symbol in data.get("symbols", []):
        key = symbol["identifier"]["precise"]
        if key not in symbols:
            symbols.add(key)
            graph["symbols"].append(symbol)
    for relationship in data.get("relationships", []):
        key = (relationship["source"], relationship["target"], relationship["kind"])
        if key not in relationships:
            relationships.add(key)
            graph["relationships"].append(relationship)

for part in parts:
    data = load(f"{part}.symbols.json")
    if main is None:
        main = new_graph(data)
    add(main, data)
for part in parts:
    for name in sorted(os.listdir(graphs)):
        if not (name.startswith(part + "@") and name.endswith(".symbols.json")):
            continue
        extended = name[len(part) + 1 : -len(".symbols.json")]
        data = load(name)
        if extended in ours:
            add(main, data)
        else:
            graph = external.setdefault(extended, new_graph(data))
            add(graph, data)

# Fold extension blocks of our own types into the types they extend.
local = {s["identifier"]["precise"] for s in main["symbols"] if s["kind"]["identifier"] != "swift.extension"}
blocks = {}
for r in main["relationships"]:
    if r["kind"] == "extensionTo" and r["target"] in local:
        blocks[r["source"]] = r["target"]
main["symbols"] = [s for s in main["symbols"] if s["identifier"]["precise"] not in blocks]
folded, keys = [], set()
for r in main["relationships"]:
    if r["kind"] == "extensionTo" and r["source"] in blocks:
        continue
    r = dict(r, source=blocks.get(r["source"], r["source"]), target=blocks.get(r["target"], r["target"]))
    key = (r["source"], r["target"], r["kind"])
    if key not in keys:
        keys.add(key)
        folded.append(r)
main["relationships"] = folded


def write(name, graph):
    # Plain UTF-8: DocC crashes on the surrogate escapes json.dump writes for emoji by default.
    with open(os.path.join(out, name), "w", encoding="utf-8") as f:
        json.dump(graph, f, ensure_ascii=False)

write("GHKit.symbols.json", main)
for extended, graph in external.items():
    write(f"GHKit@{extended}.symbols.json", graph)
print(f"Merged {len(main['symbols'])} symbols from {len(parts)} modules into GHKit", file=sys.stderr)
PY
}

archives=()
for module in "${modules[@]}"; do
    echo "==> Converting $module"
    # Each module gets its own graphs, including extensions it adds to other modules (Module@Other).
    mkdir -p "$work/graphs/$module"
    if [ "$module" = GHKit ]; then
        merge_umbrella_graphs "$work/graphs/$module"
    else
        cp "$graphs/$module.symbols.json" "$graphs/$module@"*.symbols.json "$work/graphs/$module/"
    fi

    extra=(--enable-experimental-external-link-support)
    # Let later modules link to the ones before them, e.g. GHKitUI and GHKitMCP to GHKit.
    for archive in ${archives[@]+"${archives[@]}"}; do extra+=(--dependency "$archive"); done

    docc convert "Sources/$module/$module.docc" \
        --additional-symbol-graph-dir "$work/graphs/$module" \
        --fallback-display-name "$module" \
        --fallback-bundle-identifier "com.github.${repository//\//.}.$module" \
        --output-path "$work/$module.doccarchive" \
        --diagnostics-file "$work/$module-diagnostics.json" \
        "${common[@]}" "${extra[@]}"
    check_diagnostics "$work/$module-diagnostics.json"
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
