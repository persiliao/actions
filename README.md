# reusable-actions

A collection of **reusable composite GitHub Actions / Gitea Actions** for other
repositories to reference via `uses:`. Each wrapper delegates to an existing
published action and exposes a small, typed set of inputs with sensible
defaults, so downstream CI stays consistent.

> Every action in this repo is a thin composite wrapper around an existing
> Marketplace action — nothing is hand-rolled in shell.

## Available actions

| Action | Delegates to | Key inputs |
| --- | --- | --- |
| [`checkout`](.github/actions/checkout/action.yml) | `actions/checkout@v4` | `ref`, `token`, `submodules`, `fetch-depth`, `path` |
| [`setup-node`](.github/actions/setup-node/action.yml) | `actions/setup-node@v4` | `node-version`, `cache`, `registry-url`, `token` |
| [`setup-pnpm`](.github/actions/setup-pnpm/action.yml) | `pnpm/action-setup@v4` | `version`, `run-install`, `standalone` |
| [`setup-go`](.github/actions/setup-go/action.yml) | `actions/setup-go@v5` | `go-version`, `cache`, `cache-dependency-path` |
| [`setup-python`](.github/actions/setup-python/action.yml) | `actions/setup-python@v5` | `python-version`, `cache`, `architecture` |
| [`setup-java`](.github/actions/setup-java/action.yml) | `actions/setup-java@v5` | `java-version`, `distribution`, `cache`, `server-id` |
| [`setup-maven`](.github/actions/setup-maven/action.yml) | `actions/setup-java@v5` (cache=maven) + `stCarolas/setup-maven@v4` + `s4u/maven-settings-action@v3.1.0` | `goals`, `profiles`, `maven-version`, `servers`, `mirrors` |
| [`maven-install-local`](.github/actions/maven-install-local/action.yml) | `setup-maven` (optional) + `mvn install:install-file` | `jar-file`, `pom-file`, `group-id`, `artifact-id`, `version`, `packaging`, `classifier`, `generate-pom`, `local-repo`, `setup-maven` |
| [`setup-gradle`](.github/actions/setup-gradle/action.yml) | `gradle/actions/setup-gradle@v4` | `gradle-version`, `arguments`, `cache-cleanup` |
| [`docker-build`](.github/actions/docker-build/action.yml) | `docker/login-action@v3` + `docker/build-push-action@v6` | `image`, `tags`, `registry`, `username`, `password`, `push`, `platforms` |
| [`upload-artifact`](.github/actions/upload-artifact/action.yml) | `actions/upload-artifact@v4` (GitHub) | `name`, `path`, `if-no-files-found`, `retention-days`, `overwrite` |
| [`upload-artifact-gitea`](.github/actions/upload-artifact-gitea/action.yml) | `christopherHX/gitea-upload-artifact@v4` (Gitea) | same as `upload-artifact` |
| [`download-artifact`](.github/actions/download-artifact/action.yml) | `actions/download-artifact@v4` (GitHub) | `name`, `path`, `merge-multiple`, `github-token` |
| [`download-artifact-gitea`](.github/actions/download-artifact-gitea/action.yml) | `christopherHX/gitea-download-artifact@v4` (Gitea) | same as `download-artifact` |
| [`maven-build-upload`](.github/actions/maven-build-upload/action.yml) | `checkout` + `setup-maven` + `upload-artifact` (GitHub) | `java-version`, `maven-goals`, `maven-args`, `artifact-name`, `artifact-path` |
| [`maven-build-upload-gitea`](.github/actions/maven-build-upload-gitea/action.yml) | `checkout` + `setup-maven` + `upload-artifact-gitea` (Gitea) | same as `maven-build-upload` |
| [`docker-build-push-from-artifact`](.github/actions/docker-build-push-from-artifact/action.yml) | `checkout` + `download-artifact` + `docker-build` (GitHub) | `artifact-name`, `artifact-extract-to`, `image`, `tags`, `registry`, `username`, `password`, `push` |
| [`docker-build-push-from-artifact-gitea`](.github/actions/docker-build-push-from-artifact-gitea/action.yml) | `checkout` + `download-artifact-gitea` + `docker-build` (Gitea) | same as `docker-build-push-from-artifact` |
| [`maven-docker-build-push`](.github/actions/maven-docker-build-push/action.yml) | `checkout` + `setup-maven` + `docker-build` (no cross-job artifact — JAR reused from `target/`) | `java-version`, `maven-goals`, `maven-args`, `image`, `tags`, `registry`, `username`, `password`, `push` |
| [`ssh-deploy`](.github/actions/ssh-deploy/action.yml) | `easingthemes/ssh-deploy@v5` | `host`, `port`, `username`, `key`/`password`, `source`, `target` |
| [`notify`](.github/actions/notify/action.yml) | Multi-channel — Slack (`rtCamp/action-slack-notify@v2`), Discord (`appleboy/discord-action@v1.2.0`), Telegram (`appleboy/telegram-action`), Feishu/Lark (`foxundermoon/feishu-action@v2`), DingTalk (`ghostoy/dingtalk-action`), Email (`dawidd6/action-send-mail@v3`), generic webhook (`distributhor/workflow-webhook@v1`) | `channel`, `status`, `title`, `message`, `color`, `webhook-url`, `token`, `to`, `dingtalk-secret`, `smtp-*`, `mail-*`, `webhook-secret`, `webhook-data` |

## Referencing from another repo

Reference style is identical on GitHub and Gitea:

```
uses: <OWNER>/actions/<ACTION>@<REF>
```

`<REF>` is a branch, tag, or SHA (pin to a tag/SHA in production).

### GitHub example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: persiliao/actions/checkout@main
        with:
          fetch-depth: 0          # full history for release jobs

      - uses: persiliao/actions/setup-node@main
        with:
          node-version: '20'
          cache: 'pnpm'

      - uses: persiliao/actions/docker-build@main
        with:
          image: myorg/myapp
          tags: latest ${{ github.sha }}
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          push: 'true'

      - uses: persiliao/actions/ssh-deploy@main
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_KEY }}
          source: ./dist/
          target: /var/www/app

      - uses: persiliao/actions/notify@main
        if: always()
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          status: ${{ job.status }}
          title: Build ${{ github.repository }}
          message: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

### Gitea example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: persiliao/actions/checkout@main

      - uses: persiliao/actions/setup-go@main
        with:
          go-version: '1.22'

      - uses: persiliao/actions/docker-build@main
        with:
          image: myorg/myapp
          registry: registry.example.com
          username: ${{ secrets.REG_USER }}
          password: ${{ secrets.REG_TOKEN }}
          push: 'true'
```

### Notify channel examples

The single `notify` action covers the common channels — pick one with
`channel` and pass the relevant inputs:

```yaml
steps:
  # Slack (default channel)
  - uses: persiliao/actions/notify@main
    if: always()
    with:
      webhook-url: ${{ secrets.SLACK_WEBHOOK }}
      status: ${{ job.status }}
      title: Build ${{ github.repository }}
      message: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}

  # Discord
  - uses: persiliao/actions/notify@main
    if: always()
    with:
      channel: discord
      webhook-url: ${{ secrets.DISCORD_WEBHOOK }}
      status: ${{ job.status }}

  # Telegram (needs a bot token + chat id)
  - uses: persiliao/actions/notify@main
    if: always()
    with:
      channel: telegram
      token: ${{ secrets.TELEGRAM_TOKEN }}
      to: ${{ secrets.TELEGRAM_TO }}
      message: "Build ${{ job.status }}: ${{ github.repository }}"

  # Feishu / Lark
  - uses: persiliao/actions/notify@main
    if: always()
    with:
      channel: feishu
      webhook-url: ${{ secrets.FEISHU_WEBHOOK }}
      title: Build ${{ github.repository }}
      message: ${{ job.status }}

  # DingTalk (optional 加签 secret)
  - uses: persiliao/actions/notify@main
    if: always()
    with:
      channel: dingtalk
      webhook-url: ${{ secrets.DINGTALK_WEBHOOK }}
      dingtalk-secret: ${{ secrets.DINGTALK_SECRET }}
      title: Build ${{ github.repository }}
      message: ${{ job.status }}

  # WeCom / 企业微信 (group robot webhook)
  - uses: persiliao/actions/notify@main
    if: always()
    with:
      channel: wecom
      webhook-url: ${{ secrets.WECOM_WEBHOOK }}   # 群机器人 Webhook 地址
      status: ${{ job.status }}
      title: Build ${{ github.repository }}
      message: ${{ job.status }}

  # Email
  - uses: persiliao/actions/notify@main
    if: always()
    with:
      channel: email
      smtp-server: smtp.gmail.com
      smtp-port: '465'
      smtp-username: ${{ secrets.MAIL_USERNAME }}
      smtp-password: ${{ secrets.MAIL_PASSWORD }}
      mail-to: team@example.com
      mail-from: ci@example.com
      mail-subject: Build ${{ job.status }}
      message: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}

  # Any generic webhook endpoint (Teams, custom, ...)
  - uses: persiliao/actions/notify@main
    if: always()
    with:
      channel: webhook
      webhook-url: ${{ secrets.GENERIC_WEBHOOK }}
      # optional: provide your own JSON body, otherwise a default is built
      # webhook-data: '{"@type":"MessageCard","text":"..."}'
```

## Gitea compatibility notes

These actions are designed to run on **both** GitHub and Gitea. The differences
below are the ones that actually bite — handle them and the same `uses:` works
on either platform.

- **Fetching upstream actions.** Every wrapper delegates to a published action
  on GitHub, so the Gitea instance must allow that. Set
  `[actions] DEFAULT_ACTIONS_URL = github` (the Gitea 1.21+ default) so
  short refs like `actions/checkout@v4` resolve to github.com. A fully isolated
  Gitea must vendor each upstream action locally and repoint the nested `uses:`.

- **Nested local composites resolve from the repo root.** The orchestration
  actions nest this repo's own composites via `uses: ./.github/actions/...`.
  Both GitHub and Gitea resolve that relative path against the **repository
  root** (verified with `act`). (GitHub also offers a `$/.github/actions/...`
  self-repo syntax, but Gitea support for `$/` is not guaranteed, so we use the
  portable `./` form.) Keep the `./.github/actions` tree intact if you vendor
  these actions.

- **Artifacts: `actions/upload-artifact@v4` does NOT work on Gitea.** v4
  refuses any non-github.com server (it treats Gitea as GHES and aborts). Two
  consequences:
  1. The **one-step** orchestrator `maven-docker-build-push` deliberately has
     **no upload/download step** — the built JAR stays in `target/` and your
     Dockerfile COPYs it directly, all in the same job. It needs **no**
     artifact service, so it runs on Gitea unchanged.
  2. The **split** pattern (which passes the JAR between two jobs) relies on
     artifacts. Use the dedicated Gitea variants, which delegate to the
     `christopherHX/gitea-upload-artifact@v4` / `gitea-download-artifact@v4`
     forks (a copy of v4 with the non-GitHub-server check removed):
     - `maven-build-upload-gitea` instead of `maven-build-upload`
     - `docker-build-push-from-artifact-gitea` instead of
       `docker-build-push-from-artifact`
     (Alternatively use `actions/upload-artifact@v3` / `download-artifact@v3`,
     which Gitea supports.) On GitHub, use the non-`-gitea` actions.

- **Pushing images to Gitea's registry needs a PAT.** Gitea's job token
  (`GITEA_TOKEN`, also injected as `GITHUB_TOKEN`) **cannot** publish to the
  package/OCI registry. For `docker-build`, supply a Personal Access Token with
  package-write scope as `password` when `registry` is your Gitea host. (On
  GitHub, `secrets.GITHUB_TOKEN` works directly.)

- **Contexts.** Gitea supports the `github.*` context (so `github.token`,
  `github.sha`, `github.repository`, `github.actor` all resolve — `github.token`
  maps to the Gitea job token), and also exposes a native `gitea.*` context
  (`gitea.sha`, `gitea.token`, …). Use either; `github.*` keeps one workflow
  portable to both.

- **Workflow file location.** GitHub reads `.github/workflows/`; Gitea reads
  `.gitea/workflows/`. The YAML is identical — copy the file (or symlink it) to
  the other location when you maintain both.

- **Docker-based actions.** `docker-build`, `notify` (Discord/Telegram/Feishu/
  DingTalk/**WeCom** branches), and `ssh-deploy` run Docker containers, so the Gitea
  runner must support Docker (`act_runner` in container mode, or host mode with
  a reachable Docker socket). Multi-platform `docker-build` also needs QEMU/
  binfmt registered on the runner.

## One-step pipeline (orchestration)

The composite actions above are building blocks. Two higher-level actions
compose them so a downstream repo can run the whole Java CI/CD flow by
referencing **a single action**:

```
checkout → Maven package → Docker build & push     (JAR reused from target/, no artifact needed)
```

### Option A — single import, whole flow (GitHub + Gitea)

`maven-docker-build-push` runs every stage in one job and has **no
upload/download-artifact step** — the built JAR stays in `target/` and your
Dockerfile COPYs it directly, so it needs no artifact service and runs
unchanged on both GitHub and Gitea. Just add one step:

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: persiliao/actions/maven-docker-build-push@main
        with:
          # build
          java-version: '21'
          maven-goals: 'clean package'
          maven-args: '-DskipTests -B'
          # docker (Dockerfile COPYs target/*.jar from the same workspace)
          image: myorg/myapp
          tags: latest ${{ github.sha }}
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          dockerfile: Dockerfile
          push: 'true'
```

Convention: after Maven runs, `target/*.jar` exists in the job workspace and is
part of the Docker build context (`.`). A Dockerfile such as
`COPY target/*.jar /app/app.jar` works unchanged. If you copy from a different
directory, set `context` accordingly. On Gitea, replace
`password: ${{ secrets.GITHUB_TOKEN }}` with a PAT when pushing to the Gitea
registry.

### Option B — split build / deploy jobs

For separate build and deploy stages (e.g. deploy after approval), use the two
building blocks. The artifact travels between jobs through the run store.

**GitHub:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: persiliao/actions/maven-build-upload@main
        with:
          java-version: '21'
          artifact-name: myapp-build
          artifact-path: 'target/*.jar'

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: persiliao/actions/docker-build-push-from-artifact@main
        with:
          artifact-name: myapp-build
          artifact-extract-to: 'target'
          image: myorg/myapp
          tags: latest ${{ github.sha }}
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          push: 'true'
```

**Gitea** — use the `-gitea` building blocks (the v4 artifact action refuses
non-GitHub servers), and a PAT for the registry push:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: persiliao/actions/maven-build-upload-gitea@main
        with:
          java-version: '21'
          artifact-name: myapp-build
          artifact-path: 'target/*.jar'

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: persiliao/actions/docker-build-push-from-artifact-gitea@main
        with:
          artifact-name: myapp-build
          artifact-extract-to: 'target'
          image: myorg/myapp
          tags: latest ${{ github.sha }}
          registry: registry.example.com
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_PAT }}   # PAT: GITEA_TOKEN can't push to the registry
          push: 'true'
```

`docker-build-push-from-artifact` checks out the repo first (to read the
Dockerfile / build context), then downloads the artifact, then builds and
pushes. Set `checkout: 'false'` on either building block (or the orchestrator)
only when the repo is already present in the workspace.

## Pinning for production

Prefer a tag or commit SHA over a moving branch:

```yaml
uses: persiliao/actions/docker-build@v1.2.0
# or
uses: persiliao/actions/docker-build@a1b2c3d
```

## Testing the actions with `act`

All wrappers are exercised locally with [`act`](https://github.com/nektos/act)
via `.github/workflows/test-actions.yml`. It runs each action end-to-end with
harmless inputs (no real push, deploy, or notification).

```bash
# prereqs: act (brew install act) and docker (for the docker smoke test)
./scripts/test-with-act.sh                      # run all jobs
./scripts/test-with-act.sh --job test-toolchain # run one job

# run a single job, providing a real Slack webhook for the notify dry-run:
act -s SLACK_WEBHOOK="https://hooks.slack.com/..." \
    -W .github/workflows/test-actions.yml --job test-notify-dry
```

Notes:
- `.actrc` pins a lightweight runner image and emulates `linux/amd64` so Apple
  Silicon hosts match GitHub-hosted runners.
- `test-ssh-deploy-dry` and `test-notify-dry` use `continue-on-error`: they only
  validate that inputs map correctly (status → color, source/target wiring).
  They need a live host / real webhook to fully succeed — pass secrets for a
  real run.
- `test-docker-smoke` builds a trivial image but does **not** push (`push: 'false'`).
- `test-artifact-roundtrip` exercises the upload/download wrappers and needs
  `act`'s local artifact server, which `scripts/test-with-act.sh` enables with
  `--artifact-server-path`. `test-maven-docker` exercises the
  `maven-docker-build-push` orchestrator end-to-end (no artifact server
  needed — the JAR is reused from `target/`); it pulls Maven plugins and a base
  image from the network, so allow outbound access.
- **Local memory caveat:** the `setup-gradle` job pulls the heavy Gradle
  distribution and may be OOM-killed under a memory-constrained local Docker
  VM (e.g. OrbStack's default 8 GiB) when run via `act`. The wrapper itself is
  correctly wired (it delegates to `gradle/actions/setup-gradle@v4`); on a
  real GitHub/Gitea runner it completes normally. If you need to test it
  locally, raise the Docker VM memory or test it on a host with more RAM.
- Runtime artifacts (the isolated `act-home/` used on macOS, and any
  `docker-smoke/` scratch dir) are git-ignored.

## License

MIT — see [LICENSE](LICENSE).
