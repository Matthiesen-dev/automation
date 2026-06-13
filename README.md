# matthiesen-dev/automation

Reusable GitHub Actions workflows and composite actions for release automation across Matthiesen-dev projects.

## Repository Structure

- `.github/workflows/`: reusable workflows and utility workflows.
- `.github/actions/`: reusable composite actions.
- `examples/`: ready-to-copy release workflow examples for consuming repos.
- `scripts/prepare-release.sh`: local helper for creating a release branch and pinning automation references to that branch.

## Reusable Workflows

All reusable workflows are called from other repositories using `uses: matthiesen-dev/automation/.github/workflows/<file>@<ref>`.

### Core Release Building

1. `.github/workflows/prepare-publishing.yml`
- Parses a tag (`tag_name`) into `version` and `is_snapshot`.
- Builds release artifacts and uploads them as workflow artifacts and GitHub release assets.
- Required secret: `git_token`.

2. `.github/workflows/prepare-publishing-maven.yml`
- Same as `prepare-publishing.yml`, plus publishes Maven artifacts to `maven.matthiesen.dev`.
- Intended only for projects publishing to `maven.matthiesen.dev`.
- Required secrets: `git_token`, `maven_username`, `maven_password`.

### Modrinth Publishing

3. `.github/workflows/publish-modrinth-singleloader.yml`
- Publishes one loader target (for example `fabric` or `neoforge`) to Modrinth.
- Supports overriding publish files through `modrinth_publish_files`, with automatic fallback to `output/<artifact_basename>-<loader>-<version>.jar`.
- Syncs Modrinth description from a README file.
- Required secret: `MODRINTH_TOKEN`.

4. `.github/workflows/publish-modrinth-multiloader.yml`
- Publishes both Fabric and NeoForge jars through a matrix job.
- Supports base dependencies plus loader-specific dependency overrides.
- Syncs Modrinth description from a README file.
- Required secret: `MODRINTH_TOKEN`.

### Notifications

5. `.github/workflows/notify-discord.yml`
- Builds a Discord embed payload and posts it to a webhook.
- Includes changelog, loader versions, MC version, Modrinth link, and GitHub release link.
- Required secret: `discord_webhook_url`.

### End-to-End Wrappers

6. `.github/workflows/simple-publish.yml`
- End-to-end workflow wrapper for Gradle build + Modrinth multiloader publish + Discord notify.
- Internally calls: `prepare-publishing.yml`, `publish-modrinth-multiloader.yml`, `notify-discord.yml`.
- Skips publish/notify automatically for snapshot versions.

7. `.github/workflows/simple-publish-with-maven.yml`
- Same end-to-end wrapper as `simple-publish.yml`, but uses Maven publishing during prepare.
- Internally calls: `prepare-publishing-maven.yml`, `publish-modrinth-multiloader.yml`, `notify-discord.yml`.
- Intended only for projects publishing to `maven.matthiesen.dev`.
- Skips publish/notify automatically for snapshot versions.

### Utility Workflows

8. `.github/workflows/ci-artifact.yml`
- CI helper workflow that builds with Gradle (`build copyJars`) and uploads the output as an artifact.
- Useful for pull-request build validation and artifact inspection.

9. `.github/workflows/automation-branch-release.yml`
- Manual (`workflow_dispatch`) utility for this repository.
- Creates a branch and rewrites references like `matthiesen-dev/automation/.github/...@<ref>` to your branch ref.
- Uses `scripts/prepare-release.sh` internally.

## Which Workflow Should I Use?

| Goal                                                                | Recommended Workflow                                                       | Why                                                                                               |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Fully custom pipeline stages (explicit prepare/publish/notify jobs) | `prepare-publishing.yml` + `publish-modrinth-*.yml` + `notify-discord.yml` | Maximum control over job dependencies, conditions, and per-stage overrides.                       |
| One-call Gradle release pipeline                                    | `simple-publish.yml`                                                       | Fastest setup for multiloader Modrinth + Discord with snapshot auto-skip.                         |
| One-call Gradle + Maven pipeline                                    | `simple-publish-with-maven.yml`                                            | Same convenience as simple publish, plus Maven deployment to maven.matthiesen.dev during prepare. |
| Single loader Modrinth release                                      | `publish-modrinth-singleloader.yml`                                        | Lets you target one loader or separate projects per loader.                                       |
| Build artifact only (CI / PR checks)                                | `ci-artifact.yml`                                                          | Produces and uploads build artifacts without release publishing.                                  |
| Prepare automation reference branch in this repo                    | `automation-branch-release.yml`                                            | Creates a branch and rewrites automation refs to that branch.                                     |

## Composite Actions

1. `.github/actions/java-project-setup/action.yml`
- Checkout + Java setup + Gradle setup + `gradlew` executable permissions.

2. `.github/actions/parse-version/action.yml`
- Parses tag names like `vX.Y.Z` or `X.Y.Z-SNAPSHOT`.
- Outputs `version` and `is_snapshot`.

3. `.github/actions/copy-upload-release-assets/action.yml`
- Runs `./gradlew copyJars`.
- Uploads release artifacts and attaches them to GitHub Releases.

4. `.github/actions/prepare-release/action.yml`
- Full Gradle release preparation flow.
- Uses `java-project-setup` + `copy-upload-release-assets`.

5. `.github/actions/prepare-release-with-maven/action.yml`
- Same as `prepare-release`, with additional Maven publishing step.
- Intended only for publishing to `maven.matthiesen.dev`.

6. `.github/actions/determine-dependencies/action.yml`
- Merges base and extra Modrinth dependency JSON arrays.
- Outputs `merged_dependencies`.

7. `.github/actions/optional-input-with-fallback/action.yml`
- Returns optional input if provided, otherwise required fallback input.

8. `.github/actions/build-discord-payload/action.yml`
- Builds a Discord webhook JSON payload for release announcements.
- Output: `payload`.

9. `.github/actions/send-discord-payload/action.yml`
- Sends a prebuilt Discord JSON payload to a webhook URL.

## Examples

Ready-to-copy examples are in `examples/`:

| Example                                                                                          | Description                                                                       |
| ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| [examples/multiloader-release.yml](examples/multiloader-release.yml)                             | Explicit 3-job flow: prepare + multiloader Modrinth publish + Discord notify.     |
| [examples/singleloader-release.yml](examples/singleloader-release.yml)                           | Explicit 3-job flow: prepare + singleloader Modrinth publish + Discord notify.    |
| [examples/simple-publish-release.yml](examples/simple-publish-release.yml)                       | Single wrapper job calling `simple-publish.yml` (Gradle build flow).              |
| [examples/simple-publish-with-maven-release.yml](examples/simple-publish-with-maven-release.yml) | Single wrapper job calling `simple-publish-with-maven.yml` (Gradle + Maven flow). |

All examples are triggered on published GitHub releases and pass through the release tag and changelog from the release event.

## Release Branch Helper Script

Use `scripts/prepare-release.sh` to create a branch and repoint automation references in YAML files:

```bash
bash scripts/prepare-release.sh --branch release/next --base main
```

Optional flags:

- `--commit-message <message>`
- `--no-push`

## Notes

- Pinning to `@main` picks up automation updates immediately.
- For reproducible pipelines, pin to a tag or commit SHA.