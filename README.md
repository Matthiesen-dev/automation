# Matthiesen-dev Automation Repository

Reusable GitHub Actions workflows and composite actions for release automation across Matthiesen-dev projects.

Repository: https://github.com/Matthiesen-dev/automation

## Overview

This repository provides shared automation resources for release pipelines:

- Reusable workflows for publishing Modrinth releases (singleloader and multiloader) and Discord notifications.
- Composite actions for parsing release versions and preparing Gradle release artifacts.

These resources are designed to be called from other repositories using workflow_call and local composite action references.

## Resources

### Reusable Workflows

1. .github/workflows/publish-modrinth-multiloader.yml

- Purpose: Publish Fabric and NeoForge jars to Modrinth, then sync the Modrinth project description from a README.
- Trigger: workflow_call
- Key behavior:
  - Downloads previously uploaded release artifacts.
  - Publishes two variants via matrix (fabric, neoforge).
  - Syncs Modrinth description using the configured README path.
- Required inputs:
  - artifact_basename
  - mod_name
  - version
  - changelog
  - modrinth_game_version
  - modrinth_id
- Optional inputs:
  - artifact_prefix (default: release-jars)
  - modrinth_dependencies (default: [])
  - readme_path (default: README.md)
- Required secret:
  - MODRINTH_TOKEN

2. .github/workflows/publish-modrinth-singleloader.yml

- Purpose: Publish a single loader target (for example Fabric or NeoForge) to Modrinth, then sync the Modrinth project description from a README.
- Trigger: workflow_call
- Key behavior:
  - Downloads previously uploaded release artifacts.
  - Publishes one loader selected by input.
  - Supports overriding published file glob with modrinth_publish_files.
  - Syncs Modrinth description using the configured README path.
- Required inputs:
  - artifact_basename
  - mod_name
  - version
  - changelog
  - loader
  - modrinth_game_version
  - modrinth_id
- Optional inputs:
  - artifact_prefix (default: release-jars)
  - modrinth_dependencies (default: [])
  - readme_path (default: README.md)
  - modrinth_publish_files (default behavior publishes output/<artifact_basename>-<loader>-<version>.jar)
- Required secret:
  - MODRINTH_TOKEN

3. .github/workflows/publish-discord-release.yml

- Purpose: Send a Discord webhook embed for a new release.
- Trigger: workflow_call
- Key behavior:
  - Builds a structured embed payload with release metadata.
  - Includes loader/platform info, MC version, Modrinth link, and GitHub release link.
  - Posts payload to a Discord webhook URL.
- Required inputs:
  - mod_name
  - version
- Optional inputs:
  - changelog
  - modrinth_game_version
  - modrinth_id
  - fabric_loader_version
  - neoforge_loader_version
  - discord_icon_url
  - github_release_url
  - webhook_username
  - webhook_avatar_url
- Required secret:
  - discord_webhook_url

### Composite Actions

1. .github/actions/parse-version/action.yml

- Purpose: Parse a release version from a tag string.
- Input:
  - tag_name
- Outputs:
  - version
  - is_snapshot
- Expected tag format:
  - vX.Y.Z
  - X.Y.Z
  - vX.Y.Z-SNAPSHOT
  - X.Y.Z-SNAPSHOT

2. .github/actions/prepare-release/action.yml

- Purpose: Build a Gradle project and publish release artifacts.
- Inputs:
  - version (required)
  - token (required)
  - artifact_prefix (default: release-jars)
  - java_version (default: 21)
  - java_distribution (default: temurin)
- Key behavior:
  - Checks out repository and tags.
  - Sets up Java and Gradle.
  - Runs ./gradlew build with RELEASE_VERSION.
  - Runs ./gradlew copyJars.
  - Uploads output/*.jar as workflow artifacts.
  - Uploads output/*.jar to GitHub Release assets.

## Example Usage

From another repository, call these resources like this:

```yaml
name: Release

on:
  release:
    types: [published]

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.parse.outputs.version }}
    steps:
      - name: Parse version
        id: parse
        uses: Matthiesen-dev/automation/.github/actions/parse-version@main
        with:
          tag_name: ${{ github.event.release.tag_name }}

      - name: Prepare release artifacts
        uses: Matthiesen-dev/automation/.github/actions/prepare-release@main
        with:
          version: ${{ steps.parse.outputs.version }}
          token: ${{ secrets.GITHUB_TOKEN }}

  publish_modrinth:
    needs: prepare
    uses: Matthiesen-dev/automation/.github/workflows/publish-modrinth-multiloader.yml@main
    with:
      artifact_basename: my-mod
      mod_name: My Mod
      version: ${{ needs.prepare.outputs.version }}
      changelog: ${{ github.event.release.body }}
      modrinth_game_version: "1.21.1"
      modrinth_id: your-modrinth-project-id
    secrets:
      MODRINTH_TOKEN: ${{ secrets.MODRINTH_TOKEN }}

  publish_modrinth_singleloader:
    needs: prepare
    uses: Matthiesen-dev/automation/.github/workflows/publish-modrinth-singleloader.yml@main
    with:
      artifact_basename: my-mod
      mod_name: My Mod
      version: ${{ needs.prepare.outputs.version }}
      changelog: ${{ github.event.release.body }}
      loader: fabric
      modrinth_game_version: "1.21.1"
      modrinth_id: your-modrinth-project-id
      # Optional: override file selection if your artifact naming differs
      # modrinth_publish_files: output/custom-name-*.jar
    secrets:
      MODRINTH_TOKEN: ${{ secrets.MODRINTH_TOKEN }}

  notify_discord:
    needs: prepare
    uses: Matthiesen-dev/automation/.github/workflows/publish-discord-release.yml@main
    with:
      mod_name: My Mod
      version: ${{ needs.prepare.outputs.version }}
      changelog: ${{ github.event.release.body }}
      modrinth_game_version: "1.21.1"
      modrinth_id: your-modrinth-project-id
      fabric_loader_version: "0.16.x"
      neoforge_loader_version: "21.x"
    secrets:
      discord_webhook_url: ${{ secrets.DISCORD_WEBHOOK_URL }}
```

## Notes

- If you pin to @main, updates in this repository will be picked up automatically.
- For stronger stability, pin to a tag or commit SHA in consuming repositories.