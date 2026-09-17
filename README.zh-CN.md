# persiliao/actions

一组**可复用的 GitHub 组合动作（composite actions）**，用于常见 CI/CD 任务，
既可通过 `uses:` 被其他仓库引用，也可用 [`act`](https://nektosact.com/) 在本地演练。

本仓库当前提供 **六个**组合动作。它们均**不执行 `checkout`**——假定调用方工作流
已完成代码检出。

| 动作 | 用途 | 委托对象 |
| --- | --- | --- |
| [`maven-build`](.github/actions/maven-build/action.yml) | 构建 Java / Maven 项目 | `actions/setup-java`、`stCarolas/setup-maven`（可选）、`actions/upload-artifact`（可选） |
| [`pnpm-build`](.github/actions/pnpm-build/action.yml) | 安装依赖并构建 pnpm / Node 项目 | `actions/setup-node`、`pnpm/action-setup`、`actions/cache`（可选） |
| [`docker-build-push`](.github/actions/docker-build-push/action.yml) | 使用**本地 `docker` CLI**（`docker build` + `docker push`）构建并推送 Docker 镜像 | 无——直接调用 `docker` |
| [`docker-buildx-push`](.github/actions/docker-buildx-push/action.yml) | 通过上游 **`docker/build-push-action`** 构建并推送 Docker 镜像 | `docker/setup-docker-action`、`docker/setup-qemu-action`、`docker/setup-buildx-action`、`docker/login-action`、`docker/metadata-action`、`docker/build-push-action` |
| [`scp-deploy`](.github/actions/scp-deploy/action.yml) | 通过 SCP 上传文件，支持跳板机与传输后远程命令 | `appleboy/scp-action`、`appleboy/ssh-action`（可选） |
| [`notify`](.github/actions/notify/action.yml) | 通过 Slack / 邮件 / 企业微信 / Telegram 发送 CI 通知 | `slackapi/slack-github-action`、`dawidd6/action-send-mail`、内联 `curl`、`appleboy/telegram-action` |

多数动作封装已有的上游动作；[`docker-build-push`](#docker-build-push) 是例外——它直接
驱动本地 `docker` CLI，不依赖任何外部 Action。在非 GitHub Runner（如 Gitea）上使用时，
基于上游动作的组合必须允许从 GitHub 解析——见[平台说明](#平台说明)。

## `maven-build`

校验 POM，配置 JDK（含 Maven 依赖缓存），可选地固定特定 Maven 版本，按指定目标
运行 `mvn`，统计产生的 `*.jar` / `*.war` 产物数量，并可选地将其上传。

**委托对象**

- `actions/setup-java@v6`（始终）—— 内置 `cache: maven`
- `stCarolas/setup-maven@v5` —— 仅当 `maven-version` 非空时
- `actions/upload-artifact@v4` —— 仅当 `artifact-name` 非空时

**输入**

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `java-version` | `17` | JDK 版本（如 `8`、`11`、`17`、`21`） |
| `java-distribution` | `liberica` | JDK 发行版（`temurin`、`liberica`、`zulu`、`adopt`、`microsoft`、`corretto`） |
| `maven-goals` | `clean package -DskipTests` | 要执行的 Maven 目标 |
| `maven-opts` | `-Xmx1024m` | 额外的 `MAVEN_OPTS` |
| `maven-version` | `3.9.14` | 指定的 Maven 版本（空字符串则跳过独立的 Maven 配置步骤） |
| `pom-file` | `pom.xml` | POM 文件名，用于校验与缓存依赖路径 |
| `working-directory` | `.` | 包含 `pom.xml` 的目录 |
| `skip-tests` | `true` | 为 `true` 时追加 `-DskipTests -Dmaven.test.skip=true` |
| `test-include` | _(空)_ | `-Dtest=...` 包含模式 |
| `test-exclude` | _(空)_ | `-Dtest.exclude=...` 排除模式 |
| `artifact-path` | `target/*.jar` | 上传用的产物路径（相对于 `working-directory`） |
| `artifact-name` | _(空)_ | 上传产物的名称（空 = 不上传） |

**输出**

| 名称 | 说明 |
| --- | --- |
| `build-status` | 构建步骤完成时返回 `success` |
| `artifact-count` | 找到的 `target/*.jar` / `target/*.war` 文件数量 |

**行为说明**

- 若 `${{ working-directory }}/${{ pom-file }}` 不存在，立即失败。
- 依赖缓存来自 `actions/setup-java` 的 `cache: maven`，以
  `working-directory/pom.xml` 作为缓存依赖路径。

**用法**

```yaml
steps:
  - uses: actions/checkout@v7
    with:
      fetch-depth: 1

  - uses: ./.github/actions/maven-build
    with:
      working-directory: ./spring-boot
```

在其他仓库中引用：`uses: persiliao/actions/maven-build@main`。

## `pnpm-build`

配置 Node.js 与 pnpm，可选地缓存 pnpm store 和/或 `node_modules`，然后安装依赖并
构建。该动作**不**执行检出步骤——假定仓库代码已存在。

**委托对象**

- `actions/setup-node@v7`（始终）
- `pnpm/action-setup` —— 版本按 Node.js 主版本自动选择：Node 20+ 用 `v6`，
  Node 18 用 `v4`；该 action 启用 `cache: true`。
- `actions/cache@v6` —— 仅当对应缓存输入为 `true` **且** `working-directory` 下
  存在 `pnpm-lock.yaml` 时生效（否则发出警告）

**输入**

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `node-version` | `24` | Node.js 版本（决定 `pnpm/action-setup` 的主版本） |
| `pnpm-version` | `latest` | pnpm 版本（`latest` 交由项目 `packageManager` 字段决定） |
| `working-directory` | `.` | 执行安装/构建命令的目录 |
| `install-command` | `pnpm install` | 依赖安装命令（不可为空） |
| `build-command` | `pnpm run build` | 构建命令（不可为空） |
| `cache-dependencies` | `false` | 为 `true` 时通过 `actions/cache@v6` 缓存 pnpm store |
| `cache-node-modules` | `false` | 为 `true` 时额外通过 `actions/cache@v6` 缓存 `node_modules` |

**用法**

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

## `docker-build-push`（本地 `docker` CLI）

通过直接驱动**本地 `docker` CLI 客户端**——`docker build` 与 `docker push`——来
构建并推送 Docker 镜像。它**不依赖任何外部 GitHub Action**，也**不使用 `buildx`**，
因此只要 Runner 上装有普通的 `docker` CLI（自托管、Gitea 或完全离线的 Runner，前提是
基础镜像与镜像仓库可达）即可运行。由于采用经典构建器，它**仅针对 Runner 的本地平台**
构建——没有多架构模拟。

**工作机制（无上游动作、无 buildx）**

- 校验 `registry`、`image-name`、Dockerfile 与上下文目录。
- 当设置了 `username`/`password` 时，通过 `docker login --password-stdin` 登录。
- 执行一次 `docker build`：`tags` 中每项生成一个 `--tag`，并带上 `--build-arg`、
  `--label`、`--target`、`--pull`、`--no-cache`（按需）。
- 当 `push` 为 `true` 时，用 `docker push` 推送每个标签，并从推送输出中提取 `sha256`
  digest（作为 `image-digest` 输出）；当 `push` 为 `false` 时，`image-digest` 改为
  携带本地镜像 ID。

**输入**

| 名称 | 默认值 | 必填 | 说明 |
| --- | --- | --- | --- |
| `registry` | `docker.io` | 否 | 容器镜像仓库地址（如 `ghcr.io`、`docker.io`） |
| `username` | _(空)_ | 否 | 仓库用户名（为空则跳过登录） |
| `password` | _(空)_ | 否 | 仓库密码 / Token（为空则跳过登录） |
| `image-name` | — | **是** | 镜像名（不含仓库前缀，如 `my-app`） |
| `tags` | `latest` | 否 | 逗号分隔的镜像标签 |
| `dockerfile` | `./Dockerfile` | 否 | Dockerfile 路径 |
| `context` | `.` | 否 | Docker 构建上下文目录 |
| `build-args` | _(空)_ | 否 | 构建参数（JSON 格式，如 `{"ARG1":"v1"}`） |
| `pull` | `true` | 否 | 始终尝试拉取更新的基础镜像 |
| `push` | `true` | 否 | 构建完成后推送到仓库 |
| `no-cache` | `false` | 否 | 禁用所有缓存层 |
| `target` | _(空)_ | 否 | Docker 构建目标阶段 |
| `labels` | _(空)_ | 否 | 镜像标签（JSON 格式，如 `{"org.opencontainers.image.title":"my-app"}`） |

**输出**

| 名称 | 说明 |
| --- | --- |
| `image-digest` | 推送镜像的 `sha256` digest；`push` 为 `false` 时为本地镜像 ID |
| `image-tags` | 构建/推送镜像的标签列表（逗号分隔） |

**行为说明**

- 只需 `PATH` 中存在普通 `docker` CLI——**无需 `buildx` 插件、无需 QEMU、无需 buildx
  构建器**。
- 仅针对 **Runner 的本地架构** 构建。如需多架构镜像，请改用
  [`docker-buildx-push`](#docker-buildx-push上游动作版)。
- `build-args` / `labels` 必须为合法 JSON；空字符串或 `{}` 视为「无」。
- `docker build` 使用守护进程的原生层缓存；与 buildx 版不同，没有 GHA/镜像仓库的
  缓存导入/导出。

**用法**

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
```

在其他仓库中引用：`uses: persiliao/actions/docker-build-push@main`。

## `docker-buildx-push`（上游动作版）

另一种 Docker 构建/推送动作，委托给官方的
[`docker/build-push-action`](https://github.com/docker/build-push-action) 及其配套的
`docker/setup-*` 动作，而非直接调用 `docker` CLI。若你更偏好官方维护的动作而非本地
CLI 版的 [`docker-build-push`](#docker-build-push)，可使用本动作。

**委托对象**

- `docker/setup-docker-action@v5`（始终）
- `docker/setup-qemu-action@v4` —— 仅多架构构建时
- `docker/setup-buildx-action@v4`（始终）
- `docker/login-action@v3` —— 仅当 `username` 与 `password` 均非空时
- `docker/metadata-action@v6`（始终）—— 推导标签/标签元数据
- `docker/build-push-action@v6`（始终）

**关键输入**

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `docker-version` | `latest` | 由 `docker/setup-docker-action` 安装的 Docker 版本 |
| `registry` | `docker.io` | 容器镜像仓库地址 |
| `username` / `password` | _(空)_ | 仓库凭据（为空则跳过登录） |
| `image-name` | — | **必填** —— 镜像名（不含仓库前缀） |
| `tags` | `latest` | 逗号分隔的标签；`latest` 同时受 `metadata-action` 支持 |
| `dockerfile` | `./Dockerfile` | Dockerfile 路径 |
| `context` | `.` | 构建上下文 |
| `build-args` / `secrets` | _(空)_ | JSON 映射 |
| `platforms` | `linux/amd64` | 目标平台（多架构时自动启用 QEMU + `docker-container` 构建器） |
| `pull` | `true` | 始终拉取更新的基础镜像 |
| `push` | `true` | 构建完成后推送 |
| `cache-scope` | _(空)_ | GHA 缓存作用域（为空时按分支/PR 自动推导） |
| `target` | _(空)_ | 构建目标阶段 |
| `github-token` | _(空)_ | 用于 GHCR 校验的 GitHub Token |

**输出**

| 名称 | 说明 |
| --- | --- |
| `image-digest` | 构建镜像的 digest |
| `image-tags` | 推送镜像的完整标签列表 |
| `image-labels` | 已应用镜像的标签 |

## `scp-deploy`

通过 SCP 将文件上传到远程主机，支持可选的 SSH 代理 / 跳板机（jump host）。封装了
`appleboy/scp-action@v1`。当设置了 `script` 时，会在传输完成后使用同一套鉴权/代理
配置，通过 `appleboy/ssh-action@v1` 在远程执行该命令。

**委托对象**

- `appleboy/scp-action@v1`（始终）
- `appleboy/ssh-action@v1` —— 仅当 `script` 非空时

**输入**

| 名称 | 默认值 | 必填 | 说明 |
| --- | --- | --- | --- |
| `host` | — | 是 | 目标远程主机 |
| `port` | `22` | 否 | 目标 SSH 端口 |
| `username` | — | 是 | 目标 SSH 用户名 |
| `key` | — | 否 | 目标 SSH 私钥内容 |
| `password` | — | 否 | 目标 SSH 密码 |
| `source` | — | 是 | 要上传的本地文件/目录（支持 glob） |
| `target` | — | 是 | 远程目标目录 |
| `strip_components` | `0` | 否 | 从源路径中剥离的 leading 路径元素个数 |
| `rm` | `false` | 否 | 上传前删除目标目录 |
| `overwrite` | `true` | 否 | 覆盖目标中已存在的文件 |
| `fingerprint` | — | 否 | 目标主机公钥指纹 |
| `passphrase` | — | 否 | 目标私钥的口令 |
| `timeout` | `30s` | 否 | SSH 连接超时 |
| `command_timeout` | `120s` | 否 | SCP 命令超时 |
| `proxy_host` | — | 否 | SSH 代理 / 跳板机地址 |
| `proxy_port` | `22` | 否 | 代理 SSH 端口 |
| `proxy_username` | — | 否 | 代理 SSH 用户名 |
| `proxy_key` | — | 否 | 代理 SSH 私钥内容 |
| `proxy_password` | — | 否 | 代理 SSH 密码 |
| `proxy_fingerprint` | — | 否 | 代理主机公钥指纹 |
| `proxy_passphrase` | — | 否 | 代理私钥的口令 |
| `proxy_type` | _(空)_ | 否 | 代理类型：`http`、`socks5` |
| `script` | `""` | 否 | 传输完成后在远程主机上执行的命令 |

**输出**

| 名称 | 说明 |
| --- | --- |
| `status` | 传输完成时返回 `success` |

**说明**

- 目标主机必须提供 `key` / `password` 其中之一；否则动作失败。
- 所有 `proxy_*` 输入都会透传给 `appleboy/scp-action`，从而支持经由 SSH 跳板机
  进行传输。

**用法**

```yaml
steps:
  - uses: ./.github/actions/scp-deploy
    with:
      host: ${{ secrets.DEPLOY_HOST }}
      username: ${{ secrets.DEPLOY_USER }}
      key: ${{ secrets.DEPLOY_KEY }}
      source: ./dist/
      target: /var/www/app
      # 可选跳板机
      # proxy_host: bastion.example.com
      # proxy_username: jump
      # proxy_key: ${{ secrets.JUMP_KEY }}
```

## `notify`（通知）

通过四种渠道之一发送 CI 通知 —— Slack、邮件（Email）、企业微信（WeCom）或
Telegram —— 委托给已有的第三方动作（企业微信为内联 `curl` 调用）。当 `message`
留空时，动作会自动拼装一条带 emoji 前缀、包含仓库 / 工作流 / 引用 / 触发者 /
运行链接等元数据的消息。

**渠道与委托对象**

| 渠道（`channel` 输入） | 委托对象 | 必填输入 |
| --- | --- | --- |
| `slack` | `slackapi/slack-github-action@v2` | `slack-webhook-url` |
| `email` | `dawidd6/action-send-mail@v3` | `mail-server`、`mail-to` |
| `wecom` | 内联 `curl` POST 调用企业微信 Webhook | `wecom-webhook` |
| `telegram` | `appleboy/telegram-action@v1` | `telegram-token`、`telegram-to` |

**输入**

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| `channel` | _(必填)_ | `slack` \| `email` \| `wecom` \| `telegram` |
| `status` | `success` | `success` \| `failure` \| `cancelled` \| `custom` —— 决定前缀 emoji（✅ / ❌ / ⏹️ / ℹ️） |
| `title` | `GitHub Actions Notification` | 通知标题 |
| `message` | `""` | 自定义消息；留空时自动生成含仓库 / 工作流 / 引用 / 触发者 / 运行链接的元数据消息 |
| `slack-webhook-url` | — | Slack 传入式 Webhook 地址 |
| `slack-channel` | `""` | 可选的 Slack 频道覆盖 |
| `mail-server` | — | SMTP 服务器地址 |
| `mail-port` | `465` | SMTP 服务器端口 |
| `mail-username` | — | SMTP 鉴权用户名 |
| `mail-password` | — | SMTP 鉴权密码 |
| `mail-from` | — | 发件人地址 |
| `mail-to` | — | 收件人地址 |
| `mail-subject` | `""` | 邮件主题（留空则回退到 `title`） |
| `wecom-webhook` | — | 企业微信群机器人 Webhook 地址 |
| `telegram-token` | — | Telegram Bot Token |
| `telegram-to` | — | Telegram 聊天 ID |

**输出**

| 名称 | 说明 |
| --- | --- |
| `notified` | 当所选渠道已配置其必填输入时为 `true`（与各渠道 `if:` 条件一致），否则为 `false` |

**行为说明**

- 仅当 `channel` 匹配且对应必填输入非空时，该渠道的步骤才会真正执行，其余
  步骤因 `if:` 条件被跳过。
- 自动消息包含仓库、工作流、引用、触发者与运行链接。
- 企业微信渠道仅使用普通 `curl`，不依赖任何上游动作；Slack / 邮件 / Telegram
  渠道则委托给上游动作。

**用法**

```yaml
steps:
  - uses: ./.github/actions/notify
    with:
      channel: wecom
      status: ${{ job.status }}      # success | failure | cancelled
      title: "部署完成"
      wecom-webhook: ${{ secrets.WECOM_WEBHOOK }}
```

在其他仓库中引用：`uses: persiliao/actions/notify@main`。

## 平台说明

- **GitHub 托管 Runner**：无需特殊配置，所有上游动作均从 GitHub Marketplace 解析。
- **Gitea / 其他 Runner**：组合动作以简写形式引用上游动作（`actions/*`、
  `appleboy/*`、`docker/*` 等）。实例必须允许从 GitHub 获取：设置
  `[actions] DEFAULT_ACTIONS_URL = github`（Gitea 1.21+ 默认值）。对于完全隔离的
  实例，需将这些上游动作本地化（vendored）并重新指向嵌套的 `uses:`。
- **非 GitHub 服务器上的 `upload-artifact`**：`maven-build` 仅在设置了
  `artifact-name` 时才会使用 `actions/upload-artifact@v4`。在 Gitea 上该动作会拒绝
  非 GitHub 服务器，因此请保持 `artifact-name` 为空，或改用兼容 Gitea 的产物动作。

## 使用 `act` 本地测试

`.actrc` 已为本地运行配置好：固定轻量 Runner 镜像（`catthehacker/ubuntu:*`），
模拟 `linux/amd64`（以便 Apple Silicon 主机与 GitHub 托管 Runner 保持一致），启用
`--action-offline-mode`，并从本地文件加载变量与密钥：

| 文件 | 用途 | 是否忽略 |
| --- | --- | --- |
| `.env` | 环境变量（`--env-file`） | 是 |
| `.secrets` | 密钥（`--secret-file`） | 是 |
| `.vars` | 工作流变量（`--var-file`） | 否 |
| `.inputs` | 手动 `workflow_dispatch` 输入（`--input-file`） | 否 |

> 本仓库未提交端到端示例工作流。请自行编写引用这些动作（通过 `uses:`）的工作流，
> 然后运行，例如 `act -W path/to/your/workflow.yml`。

## 许可证

MIT —— 详见 [LICENSE](LICENSE)。
