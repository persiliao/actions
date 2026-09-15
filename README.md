# persiliao/actions

A collection of **reusable composite GitHub Actions** for common CI/CD tasks,
designed to be referenced from other repositories via `uses:` or exercised
locally with [`act`](https://nektosact.com/).

The repository currently ships **five** composite actions. None of them performs
a `checkout` — they assume the calling workflow has already checked out the code.

| Action | Purpose | Delegates to |
| --- | --- | --- |
| [`maven-build`](.github/actions/maven-build/action.yml) | Build Java / Maven projects | `actions/setup-java`, `stCarolas/setup-maven` (optional), `actions/upload-artifact` (optional) |
| [`pnpm-build`](.github/actions/pnpm-build/action.yml) | Install dependencies & build pnpm / Node projects | `actions/setup-node`, `pnpm/action-setup`, `actions/cache` (optional) |
| [`docker-build-push`](.github/actions/docker-build-push/action.yml) | Build & push multi-architecture Docker images with caching | `docker/setup-qemu-action`, `docker/setup-buildx-action`, `docker/login-action` (optional), `docker/metadata-action`, `docker/build-push-action` |
| [`scp-deploy`](.github/actions/scp-deploy/action.yml) | Upload files over SCP, with optional jump host & post-transfer command | `appleboy/scp-action`, `appleboy/ssh-action` (optional) |
| [`notify`](.github/actions/notify/action.yml) | Send CI notifications via Slack / Email / WeCom / Telegram | `slackapi/slack-github-action`, `dawidd6/action-send-mail`, inline `curl`, `appleboy/telegram-action` |

All actions are `using: composite` and wrap upstream published actions. When used
on a non-GitHub runner (e.g. Gitea) the upstream actions must be resolvable from
GitHub — see [Platform notes](#platform-notes).

## `maven-build`

Validates the POM, sets up the JDK (with Maven dependency caching), optionally
pins a specific Maven version, runs `mvn` with the requested goals, counts the
produced `*.jar` / `*.war` artifacts, and optionally uploads them.

**Delegates to**

- `actions/setup-java@v6` (always) — with built-in `cache: maven`
- `stCarolas/setup-maven@v5` — only when `maven-version` is non-empty
- `actions/upload-artifact@v4` — only when `artifact-name` is non-empty

**Inputs**

| Name | Default | Description |
| --- | --- | --- |
| `java-version` | `17` | JDK version (e.g. `8`, `11`, `17`, `21`) |
| `java-distribution` | `liberica` | JDK distribution (`temurin`, `liberica`, `zulu`, `adopt`, `microsoft`, `corretto`) |
| `maven-goals` | `clean package -DskipTests` | Maven goals to execute |
| `maven-opts` | `-Xmx1024m` | Extra `MAVEN_OPTS` |
| `maven-version` | `3.9.14` | Specific Maven version (empty string skips the standalone Maven setup) |
| `pom-file` | `pom.xml` | POM filename, used for validation and the cache dependency path |
| `working-directory` | `.` | Directory containing the `pom.xml` |
| `skip-tests` | `true` | When `true`, appends `-DskipTests -Dmaven.test.skip=true` |
| `test-include` | _(empty)_ | `-Dtest=...` inclusion pattern |
| `test-exclude` | _(empty)_ | `-Dtest.exclude=...` exclusion pattern |
| `artifact-path` | `target/*.jar` | Artifact path (relative to `working-directory`) for upload |
| `artifact-name` | _(empty)_ | Name for the uploaded artifact (empty = no upload) |

**Outputs**

| Name | Description |
| --- | --- |
| `build-status` | `success` once the build step completes |
| `artifact-count` | Number of `target/*.jar` / `target/*.war` files found |

**Behavior notes**

- Fails fast if `${{ working-directory }}/${{ pom-file }}` does not exist.
- Dependency caching comes from `actions/setup-java`'s `cache: maven`, keyed on
  `working-directory/pom.xml`.

**Usage**

```yaml
steps:
  - uses: actions/checkout@v7
    with:
      fetch-depth: 1

  - uses: ./.github/actions/maven-build
    with:
      working-directory: ./spring-boot
```

From another repository: `uses: persiliao/actions/maven-build@main`.

## `pnpm-build`

Sets up Node.js and pnpm, optionally caches the pnpm store and/or `node_modules`,
then installs dependencies and builds. **No `checkout` is performed** — the
repository is assumed to be already present.

**Delegates to**

- `actions/setup-node@v7` (always)
- `pnpm/action-setup` — version is chosen by the Node.js major version: `v6` for
  Node 20+, `v4` for Node 18. `cache: true` is enabled on the action.
- `actions/cache@v6` — only when the corresponding cache input is `true` **and**
  `pnpm-lock.yaml` exists in `working-directory` (a warning is emitted otherwise)

**Inputs**

| Name | Default | Description |
| --- | --- | --- |
| `node-version` | `24` | Node.js version (drives the `pnpm/action-setup` major version) |
| `pnpm-version` | `latest` | pnpm version (`latest` lets the project's `packageManager` field decide) |
| `working-directory` | `.` | Directory for install/build commands |
| `install-command` | `pnpm install` | Dependency install command (must not be empty) |
| `build-command` | `pnpm run build` | Build command (must not be empty) |
| `cache-dependencies` | `false` | When `true`, caches the pnpm store via `actions/cache@v6` |
| `cache-node-modules` | `false` | When `true`, also caches `node_modules` via `actions/cache@v6` |

**Usage**

```yaml
steps:
  - uses: actions/checkout@v7
    with:
      fetch-depth: 1

  - uses: ./.github/actions/pnpm-build
    with:
      working-directory: ./vue
      cache-dependencies: true
      install-command: pnpm install --frozen-lockfile
      build-command: pnpm run build
```

## `docker-build-push`

Builds a Docker image with Buildx (optionally multi-arch) and pushes it to a
registry. Supports registry login, OCI metadata/labels, build args, build
secrets, a build target stage, and GHA/registry layer caching. When `push` is
`false` it builds only (useful for PR validation).

**Delegates to**

- `docker/setup-qemu-action@v3` (always) — multi-arch emulation
- `docker/setup-buildx-action@v3` (always)
- `docker/login-action@v3` — only when `username` and `password` are both set
- `docker/metadata-action@v5` (always) — derives tags/labels
- `docker/build-push-action@v6` (always) — emits `provenance` + `sbom`

**Inputs**

| Name | Default | Required | Description |
| --- | --- | --- | --- |
| `registry` | `docker.io` | no | Container registry URL (e.g. `ghcr.io`, `docker.io`) |
| `username` | _(empty)_ | no | Registry username (login skipped if empty) |
| `password` | _(empty)_ | no | Registry password / token (login skipped if empty) |
| `image-name` | — | **yes** | Image name without registry prefix (e.g. `my-app`) |
| `tags` | `latest` | no | Comma-separated image tags |
| `dockerfile` | `./Dockerfile` | no | Path to the Dockerfile |
| `context` | `.` | no | Docker build context directory |
| `build-args` | _(empty)_ | no | Build arguments as JSON, e.g. `{"ARG1":"v1"}` |
| `platforms` | `linux/amd64` | no | Comma-separated target platforms (e.g. `linux/amd64,linux/arm64`) |
| `push` | `true` | no | Push to the registry after build |
| `cache-from` | `type=gha` | no | Cache import source |
| `cache-to` | `type=gha,mode=max` | no | Cache export destination |
| `target` | _(empty)_ | no | Docker build target stage |
| `secrets` | _(empty)_ | no | Build secrets as JSON, e.g. `{"TOKEN":"xxx"}` (exported as env for the build) |

**Outputs**

| Name | Description |
| --- | --- |
| `image-digest` | Digest of the built image |
| `image-tags` | Full list of pushed image tags |

**Behavior notes**

- Tags are also augmented by `docker/metadata-action`: a short `sha` tag and a
  `latest` tag on the default branch are appended automatically.
- `build-args` / `secrets` must be valid JSON; an empty string or `{}` is treated
  as "no args / no secrets".
- `provenance` and `sbom` are enabled (`provenance: mode=max`, `sbom: true`).

**Usage**

```yaml
steps:
  - uses: actions/checkout@v7
    with:
      fetch-depth: 1

  - uses: ./.github/actions/docker-build-push
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}
      image-name: persiliao/my-app
      tags: ${{ github.sha }},latest
      platforms: linux/amd64,linux/arm64
```

## `scp-deploy`

Uploads files to a remote host over SCP, with optional SSH proxy / jump-host
support. Wraps `appleboy/scp-action@v1`. When `script` is set, a follow-up
remote command runs via `appleboy/ssh-action@v1` using the same auth/proxy config.

**Delegates to**

- `appleboy/scp-action@v1` (always)
- `appleboy/ssh-action@v1` — only when `script` is non-empty

**Inputs**

| Name | Default | Required | Description |
| --- | --- | --- | --- |
| `host` | — | yes | Target remote host |
| `port` | `22` | no | Target SSH port |
| `username` | — | yes | Target SSH username |
| `key` | — | no | Target SSH private key content |
| `password` | — | no | Target SSH password |
| `source` | — | yes | Local file(s)/directory to upload (glob supported) |
| `target` | — | yes | Remote target directory |
| `strip_components` | `0` | no | Strip leading path elements from source |
| `rm` | `false` | no | Remove target folder before upload |
| `overwrite` | `true` | no | Overwrite existing files |
| `fingerprint` | — | no | Target host public-key fingerprint |
| `passphrase` | — | no | Passphrase for the target private key |
| `timeout` | `30s` | no | SSH connection timeout |
| `command_timeout` | `120s` | no | SCP command timeout |
| `proxy_host` | — | no | SSH proxy / jump-host address |
| `proxy_port` | `22` | no | Proxy SSH port |
| `proxy_username` | — | no | Proxy SSH username |
| `proxy_key` | — | no | Proxy SSH private key content |
| `proxy_password` | — | no | Proxy SSH password |
| `proxy_fingerprint` | — | no | Proxy host public-key fingerprint |
| `proxy_passphrase` | — | no | Passphrase for the proxy private key |
| `proxy_type` | _(empty)_ | no | Proxy type: `http`, `socks5` |
| `script` | `""` | no | Command executed on the remote host after the SCP transfer |

**Outputs**

| Name | Description |
| --- | --- |
| `status` | `success` when the transfer completes |

**Notes**

- Exactly one of `key` / `password` must be provided for the target host; the
  action fails otherwise.
- All `proxy_*` inputs are forwarded to `appleboy/scp-action`, enabling transfers
  through an SSH jump host.

**Usage**

```yaml
steps:
  - uses: ./.github/actions/scp-deploy
    with:
      host: ${{ secrets.DEPLOY_HOST }}
      username: ${{ secrets.DEPLOY_USER }}
      key: ${{ secrets.DEPLOY_KEY }}
      source: ./dist/
      target: /var/www/app
      # optional jump host
      # proxy_host: bastion.example.com
      # proxy_username: jump
      # proxy_key: ${{ secrets.JUMP_KEY }}
```

## `notify`

Sends a CI notification through one of four channels — Slack, Email,
WeCom (企业微信), or Telegram — by delegating to an existing third-party action
(or an inline `curl` call for WeCom). When `message` is empty, an
emoji-prefixed message is auto-built from the repository / workflow / ref / actor
/ run metadata.

**Channels & delegates**

| Channel (`channel` input) | Delegates to | Required inputs |
| --- | --- | --- |
| `slack` | `slackapi/slack-github-action@v2` | `slack-webhook-url` |
| `email` | `dawidd6/action-send-mail@v3` | `mail-server`, `mail-to` |
| `wecom` | inline `curl` POST to the WeCom webhook | `wecom-webhook` |
| `telegram` | `appleboy/telegram-action@v1` | `telegram-token`, `telegram-to` |

**Inputs**

| Name | Default | Description |
| --- | --- | --- |
| `channel` | _(required)_ | `slack` \| `email` \| `wecom` \| `telegram` |
| `status` | `success` | `success` \| `failure` \| `cancelled` \| `custom` — selects the leading emoji (✅ / ❌ / ⏹️ / ℹ️) |
| `title` | `GitHub Actions Notification` | Notification title |
| `message` | `""` | Custom message; when empty, an auto message with repo / workflow / ref / actor / run URL is built |
| `slack-webhook-url` | — | Incoming-webhook URL for Slack |
| `slack-channel` | `""` | Optional Slack channel override |
| `mail-server` | — | SMTP server address |
| `mail-port` | `465` | SMTP server port |
| `mail-username` | — | SMTP auth username |
| `mail-password` | — | SMTP auth password |
| `mail-from` | — | Sender address |
| `mail-to` | — | Recipient address |
| `mail-subject` | `""` | Mail subject (falls back to `title` when empty) |
| `wecom-webhook` | — | WeCom (企业微信) group-robot webhook URL |
| `telegram-token` | — | Telegram bot token |
| `telegram-to` | — | Telegram chat id |

**Outputs**

| Name | Description |
| --- | --- |
| `notified` | `true` when the selected channel is configured with its required inputs (mirrors the per-channel `if:` conditions); `false` otherwise |

**Behavior notes**

- Only the step matching `channel` (and having its required inputs populated) fires;
  the other channel steps are skipped via `if:` conditions.
- The auto message embeds the repository, workflow, ref, actor, and run URL.
- The WeCom channel uses plain `curl` and has no upstream-action dependency; the
  Slack / Email / Telegram channels delegate to upstream actions.

**Usage**

```yaml
steps:
  - uses: ./.github/actions/notify
    with:
      channel: wecom
      status: ${{ job.status }}      # success | failure | cancelled
      title: "Deploy finished"
      wecom-webhook: ${{ secrets.WECOM_WEBHOOK }}
```

From another repository: `uses: persiliao/actions/notify@main`.

## Platform notes

- **GitHub-hosted runners**: nothing special required; all upstream actions
  resolve from the GitHub Marketplace.
- **Gitea / other runners**: the composites reference upstream actions by short
  name (`actions/*`, `appleboy/*`, `docker/*`, …). The instance must allow
  fetching them from GitHub — set `[actions] DEFAULT_ACTIONS_URL = github`
  (the Gitea 1.21+ default). For a fully isolated instance, vendor those upstream
  actions locally and repoint the nested `uses:`.
- **`upload-artifact` on non-GitHub servers**: `maven-build` uses
  `actions/upload-artifact@v4` only when `artifact-name` is set. On Gitea that
  action refuses non-GitHub servers, so leave `artifact-name` empty there or
  switch to a Gitea-compatible artifact action.

## Local testing with `act`

`.actrc` is preconfigured for local runs: it pins lightweight runner images
(`catthehacker/ubuntu:*`), emulates `linux/amd64` (so Apple Silicon hosts match
GitHub-hosted runners), enables `--action-offline-mode`, and loads variables and
secrets from local files:

| File | Purpose | Git-ignored? |
| --- | --- | --- |
| `.env` | Environment variables (`--env-file`) | yes |
| `.secrets` | Encrypted secrets (`--secret-file`) | yes |
| `.vars` | Workflow variables (`--var-file`) | no |
| `.inputs` | Manual `workflow_dispatch` inputs (`--input-file`) | no |

> No end-to-end example workflows are committed in this repository. Compose your
> own workflow that references these actions via `uses:`, then run e.g.
> `act -W path/to/your/workflow.yml`.

## License

MIT — see [LICENSE](LICENSE).
