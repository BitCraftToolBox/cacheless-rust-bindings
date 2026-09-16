#!/usr/bin/env bash
set -e

repo_root=$(pwd)

hostname=${BITCRAFT_SPACETIME_HOST:-bitcraft-early-access.spacetimedb.com}
global_mod=${BITCRAFT_GLOBAL_MODULE:-bitcraft-live-global}
region_mod=${BITCRAFT_REGION_MODULE:-bitcraft-live-2}

test -d src/global && rm -r src/global
test -d src/region && rm -r src/region

# spacetime 2.x's `generate` hides --module-def from --help and only reaches
# it once an unrelated "does a buildable module exist" check passes. A dummy
# spacetimedb/ directory in the generate cwd satisfies that check without
# spacetime ever looking inside it.
scratch_dir=$(mktemp -d)
mkdir -p "$scratch_dir/spacetimedb"

generate() {
  local db=$1 out=$2
  curl --fail "https://${hostname}/v1/database/${db}/schema?version=10" | jq '{"V10": .}' > "$repo_root/schema.json"
  # don't --include-private here, not that it makes a huge difference. we drop a few unnecessary tables, but reducers
  # are pretty much all public and sender-gated instead.
  (cd "$scratch_dir" && spacetime generate -y --module-def "$repo_root/schema.json" --lang rs --out-dir "$repo_root/$out")
  rm "$repo_root/schema.json"
}

generate ${global_mod} src/global

generate ${region_mod} src/region

rm -rf "$scratch_dir"

# patch all DbUpdate fields to be pub
perl -i -pe '/pub struct DbUpdate \{/ .. /^\}/ and s/^(\s+)(\w+:[^:])/$1pub $2/' src/global/mod.rs src/region/mod.rs

perl -i -pe "s/^version = .*$/version = \"$(date -u +%Y.%-m.%-d)\"/" Cargo.toml
