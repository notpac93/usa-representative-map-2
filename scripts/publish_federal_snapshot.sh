#!/usr/bin/env bash
# Publish prepared local data in a separate checkout. Never force-update history.
set -euo pipefail
federal_repo=$(git rev-parse --show-toplevel)
python3 "$federal_repo/scripts/federal_data_pipeline.py" --verify-published
federal_temp=$(mktemp -d)
federal_tree="$federal_temp/tree"
cleanup() {
  git -C "$federal_repo" worktree remove --force "$federal_tree" >/dev/null 2>&1 || true
  rm -rf "$federal_temp"
}
trap cleanup EXIT
if git ls-remote --exit-code --heads origin codex/federal-snapshots; then
  git fetch origin refs/heads/codex/federal-snapshots
  git worktree add --detach "$federal_tree" FETCH_HEAD
  python3 "$federal_repo/scripts/federal_data_pipeline.py" --verify-published --expected-previous "$federal_tree/assets/data/federal_officials.json"
else
  federal_remote_status=$?
  if [ "$federal_remote_status" -ne 2 ]; then exit "$federal_remote_status"; fi
  git worktree add --detach "$federal_tree" HEAD
  git -C "$federal_tree" checkout --orphan codex/federal-snapshots
  git -C "$federal_tree" rm -rf .
fi
mkdir -p "$federal_tree/assets/data" "$federal_tree/data"
cp "$federal_repo/assets/data/federal_officials.json" "$federal_tree/assets/data/"
cp -R "$federal_repo/data/federal" "$federal_tree/data/"
git -C "$federal_tree" config user.name 'github-actions[bot]'
git -C "$federal_tree" config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git -C "$federal_tree" add assets/data/federal_officials.json data/federal
if git -C "$federal_tree" diff --cached --quiet; then
  echo 'Published files already match; no remote update needed.'
  exit 0
fi
git -C "$federal_tree" commit -m 'Publish checked federal officials and recovery evidence'
git -C "$federal_tree" push origin HEAD:refs/heads/codex/federal-snapshots
