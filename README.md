# Matthiesen-dev Automation Repository

Reusable GitHub Actions workflows and composite actions for release automation across Matthiesen-dev projects.

## Overview

This repository provides shared automation resources for release pipelines:

- Reusable workflows for preparing releases and publishing to Modrinth (singleloader and multiloader) and Discord.
- Composite actions for parsing release versions, preparing Gradle release artifacts, and building Discord embed payloads.

These resources are designed to be called from other repositories using workflow_call and local composite action references.

## Resources

### Reusable Workflows

1. .github/workflows/prepare-publishing.yml

- Purpose: Parse a release tag and build/upload Gradle release artifacts in a single reusable workflow step. Use this instead of calling parse-version and prepare-release actions individually.
- Trigger: workflow_call
- Outputs:
  - version
  - is_snapshot
- Required inputs:
  - tag_name
- Required secret:
  - GITHUB_TOKEN (automatically provided by GitHub)

2. .github/workflows/publish-modrinth-multiloader.yml

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

3. .github/workflows/publish-modrinth-singleloader.yml

- Purpose: Publish a single loader target (for example Fabric or NeoForge) to Modrinth, then sync the Modrinth project description from a README.
- Trigger: workflow_call
- Key behavior:
  - Downloads previously uploaded release artifacts.
  - Publishes one loader selected by input.
  - Delegates file selection to the optional-input-with-fallback action (uses modrinth_publish_files if provided, otherwise derives the path from artifact_basename, loader, and version).
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

4. .github/workflows/publish-discord-release.yml

- Purpose: Send a Discord webhook embed for a new release.
- Trigger: workflow_call
- Key behavior:
  - Delegates payload construction to the build-discord-payload composite action.
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

1. .github/actions/build-discord-payload/action.yml

- Purpose: Build a Discord webhook embed JSON payload for a release notification.
- Inputs:
  - mod_name (required)
  - version (required)
  - changelog
  - modrinth_game_version
  - modrinth_id
  - fabric_loader_version
  - neoforge_loader_version
  - discord_icon_url
  - github_release_url
  - webhook_username (default: Matthiesen Release Bot)
  - webhook_avatar_url
- Output:
  - payload

2. .github/actions/parse-version/action.yml

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

3. .github/actions/prepare-release/action.yml

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

4. .github/actions/optional-input-with-fallback/action.yml

- Purpose: Return an optional input value if provided, otherwise return a required fallback value. Used internally by publish-modrinth-singleloader to resolve the publish file path.
- Inputs:
  - optional_input (optional)
  - fallback_input (required)
- Output:
  - result

5. .github/actions/send-discord-payload/action.yml

- Purpose: Send a prepared Discord webhook JSON payload to a Discord webhook URL.
- Inputs:
  - payload (required)
  - discord_webhook_url (required)

## Examples

Ready-to-copy release workflow examples live in the [examples/](examples/) folder:

| Example                                                                | Description                                                                            |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| [examples/multiloader-release.yml](examples/multiloader-release.yml)   | Publish Fabric and NeoForge jars to Modrinth in a single release, then notify Discord. |
| [examples/singleloader-release.yml](examples/singleloader-release.yml) | Publish a single loader target to Modrinth, then notify Discord.                       |

All examples follow the same basic structure:

1. `prepare` — calls `prepare-publishing.yml` to parse the tag and build/upload artifacts.
2. `publish_modrinth` — calls the appropriate Modrinth publish workflow.
3. `notify_discord` — calls `publish-discord-release.yml` after publishing completes.

## Notes

- If you pin to @main, updates in this repository will be picked up automatically.
- For stronger stability, pin to a tag or commit SHA in consuming repositories.