#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# build-pack.sh — Zips the pack, honouring .packignore exclusions.
#
# Usage:
#   ./scripts/build-pack.sh PACK_NAME [VERSION]
#
#   If VERSION is omitted the script derives a version from
#   the current git tag (or short commit hash when no tag is present):
#     my-pack-v1.0.0.zip
#     my-pack-dev-a1b2c3d.zip
# ---------------------------------------------------------------------------

# Resolve the repo root regardless of where the script is called from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Parse args.
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 PACK_NAME [VERSION]" >&2
  exit 1
fi

PACK_NAME="$1"

# Determine version.
if [[ $# -ge 2 ]]; then
  VERSION="$2"
else
  if git describe --exact-match --tags HEAD 2>/dev/null; then
    VERSION="$(git describe --exact-match --tags HEAD)"
  else
    VERSION="dev-$(git rev-parse --short HEAD)"
  fi
fi

# Build output filename from pack name and version.
FILENAME="${PACK_NAME}-${VERSION}.zip"

# Parse .packignore into zip exclusion args.
# Directory entries (trailing /) are expanded to match all contents.
EXCLUDES=()
if [[ -f .packignore ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and comments.
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == */ ]]; then
      EXCLUDES+=("-x" "${line}*")
    else
      EXCLUDES+=("-x" "$line")
    fi
  done < .packignore
fi

# Always exclude .packignore itself and .git.
EXCLUDES+=("-x" ".packignore" "-x" ".git" "-x" ".git/*")

echo "Building: $FILENAME"
zip -r "$FILENAME" . "${EXCLUDES[@]}"
echo "Done: $FILENAME"
