#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/prepare-release.sh --branch <branch-name> [--base <base-branch>] [--commit-message <message>] [--no-push]

Creates a new branch, updates all references that match:
	matthiesen-dev/automation/.github/...@<ref>
and rewrites them to:
	matthiesen-dev/automation/.github/...@<branch-name>

Then commits the changes and, unless --no-push is provided, pushes the branch to origin.
EOF
}

BRANCH_NAME=""
BASE_BRANCH="main"
COMMIT_MESSAGE=""
PUSH_BRANCH="true"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--branch)
			BRANCH_NAME="${2:-}"
			shift 2
			;;
		--base)
			BASE_BRANCH="${2:-}"
			shift 2
			;;
		--commit-message)
			COMMIT_MESSAGE="${2:-}"
			shift 2
			;;
		--no-push)
			PUSH_BRANCH="false"
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage
			exit 1
			;;
	esac
done

if [[ -z "$BRANCH_NAME" ]]; then
	echo "--branch is required." >&2
	usage
	exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "This script must be run inside a git repository." >&2
	exit 1
fi

if [[ -z "$COMMIT_MESSAGE" ]]; then
	COMMIT_MESSAGE="chore: prepare release branch ${BRANCH_NAME}"
fi

echo "Fetching latest refs from origin..."
git fetch origin "$BASE_BRANCH"

echo "Creating branch '${BRANCH_NAME}' from origin/${BASE_BRANCH}..."
git checkout -B "$BRANCH_NAME" "origin/$BASE_BRANCH"

TARGET_BRANCH="$BRANCH_NAME"
export TARGET_BRANCH

echo "Updating action/workflow references to @${BRANCH_NAME}..."
mapfile -t YAML_FILES < <(git ls-files '*.yml' '*.yaml')

if [[ ${#YAML_FILES[@]} -eq 0 ]]; then
	echo "No YAML files found. Nothing to update."
	exit 0
fi

for file in "${YAML_FILES[@]}"; do
	perl -i -pe 's{(?i)\bmatthiesen-dev/automation/\.github/([^@\s]+)@[A-Za-z0-9._/-]+}{"matthiesen-dev/automation/.github/$1@$ENV{TARGET_BRANCH}"}ge' "$file"
done

if [[ -z "$(git status --porcelain)" ]]; then
	echo "No changes detected after reference update."
	exit 0
fi

echo "Committing updated references..."
git add '*.yml' '*.yaml'
git commit -m "$COMMIT_MESSAGE"

if [[ "$PUSH_BRANCH" == "true" ]]; then
	echo "Pushing '${BRANCH_NAME}' to origin..."
	git push -u origin "$BRANCH_NAME"
else
	echo "Push skipped (--no-push provided)."
fi

echo "Release branch preparation complete."
