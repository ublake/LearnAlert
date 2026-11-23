#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
playbook_url=https://github.com/mjmirza/app-store-compliance.git
# App Store Compliance Playbook v2.5.1.
playbook_revision=54c2e33254448a545fa2bcb25b3adfef984cf9dc

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/learnalert-app-store.XXXXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

playbook_dir="$work_dir/playbook"
scan_dir="$work_dir/LearnAlert"
git init --quiet "$playbook_dir"
git -C "$playbook_dir" fetch --quiet --depth=1 "$playbook_url" "$playbook_revision"
git -C "$playbook_dir" checkout --quiet --detach "$playbook_revision"

# Scan the working copy, including pending release edits. Omit local tools and
# build products that can look like shipping code to the source scanner.
rsync -a \
    --exclude='.git' \
    --exclude='/.agents/' \
    --exclude='/.impeccable/' \
    --exclude='/side-repos/' \
    --exclude='/Pods/' \
    --exclude='/build/' \
    --exclude='.build/' \
    --exclude='DerivedData/' \
    --exclude='xcuserdata/' \
    "$project_dir/" "$scan_dir/"

printf 'LearnAlert checkout: %s\n' "$project_dir"
bash "$playbook_dir/agent-os/hooks/app-store-compliance-guard.sh" "$scan_dir"
