# Hermes Agent（Docker Compose）

本目录提供一份 **Docker Compose** 示例：网关常驻、Dashboard、HTTP API（含 **`/health`**）。目录与行为对齐官方：[Docker 用户指南（简体中文）](https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/docker)。

---

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | **`nousresearch/hermes-agent`**（默认 **`latest`**，生产建议改为明确 digest 或标签，避免漂移） |
| 数据 | 命名卷 **`hermes-agent-data`** → 容器内 **`/opt/data`** |
| 网关 API | **`8642`**（OpenAI 兼容） |
| 健康检查 | 无 Compose **`healthcheck`**；验证用网关 **`GET /health`**（见部署第 4 步） |
| 可视化 / 管理 | **Dashboard**：**`http://<本机IP>:9119`** |
| 对外监听 | 端口映射到宿主机 **所有网卡**；公网务必 **防火墙 + 强 `API_SERVER_KEY`** |

---

## 部署

建议顺序：**环境变量 → 首次 `setup` → 后台启动 → 验证**。聊天平台绑定见下方 **日常使用**。

### 1. 复制并编辑环境变量

```bash
cp .env.example .env
```

编辑 **`.env`**：至少将 **`API_SERVER_KEY`** 改为 **≥8 位** 随机串（可用 `openssl rand -hex 16`）。

### 2. 首次向导（`setup`，写入卷内基础配置）

```bash
docker compose run --rm hermes-agent setup
```

向导末尾 **`Launch hermes chat now? [Y/n]:`**：选 **`n`** 退出后继续；选 **`Y`** 可在容器里先试 CLI。

### 3. 后台启动

```bash
docker compose up -d
```

### 4. 验证与访问

```bash
docker compose ps
```

**健康检查**：容器为 **`running`** 后，本机请求 **`GET /health`**（把 `127.0.0.1` 换成你的机器 IP 亦可）。

Windows（PowerShell / CMD，避免 `curl` 别名）：

```bash
curl.exe -s http://127.0.0.1:8642/health
```

Linux / macOS：

```bash
curl -s http://127.0.0.1:8642/health
```

**Dashboard**：`http://<本机IP>:9119`

---

## 日常使用

### 聊天平台绑定（`gateway setup`）

Hermes 自带 **`hermes gateway setup`**：菜单里选微信 / 飞书 / Telegram 等，按提示扫码或填 **App ID、Secret**，凭证写入卷内配置，无需手改文件。

**Docker**（与本 Compose 同一份数据卷）：若尚未 **`up -d`**，可直接：

```bash
docker compose run --rm -it hermes-agent gateway setup
```

若网关已在跑，先停再跑向导，避免双写 **`/opt/data`**：

```bash
docker compose stop
docker compose run --rm -it hermes-agent gateway setup
docker compose up -d
```

也可（自担并发风险）：`docker exec -it hermes-agent /opt/hermes/.venv/bin/hermes gateway setup`。

### 终端里聊天（TUI）

在 **`docker compose up -d` 已运行** 的前提下，在本机终端执行：

```bash
docker exec -it hermes-agent /opt/hermes/.venv/bin/hermes --tui
```

退出终端即结束本次 TUI；网关仍在后台跑。详见 [TUI（简体中文）](https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/tui)。

**为何不写 `-u hermes`**：在 **Windows + Docker Desktop** 下，常见 **引擎/数据在 D 盘、WSL 多在 C 盘**，再叠非 root 用户与卷权限时容易别扭；本机自用省略 `-u hermes` 通常最省事。纯 Linux 且权限干净时可自行加上 `-u hermes`。

**与网关同时跑**：TUI 与网关共用 **`/opt/data`**，自用一般无妨；若要严格隔离，可先 **`docker compose stop`** 再开 TUI。

### 改配置 / 看数据卷内容

命名卷名：**`hermes-agent-data`**。进容器后编辑 **`/opt/data`**：

```bash
docker exec -it hermes-agent sh
```

备份与升级参见 [官方 Docker 说明](https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/docker)。

---

## 附：给 AI 重生成本目录用的约束

以下条目可整体粘贴进提示词（本 Compose 当时按此约束生成）：

1. **对齐官方**：[Hermes Agent — Docker（简体中文）](https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/docker)；数据 **`/opt/data`**；不改镜像 entrypoint；主命令 **`gateway run`**；按需 **`HERMES_DASHBOARD`**。
2. **端口**：需在 Compose **`ports`** 中映射 **8642**、**9119**。
3. **第三方可调网关**：**`API_SERVER_ENABLED`**、**`API_SERVER_HOST=0.0.0.0`**、**`API_SERVER_KEY`**（≥8）；**`/health`** 可浏览器或 curl；注明公网风险。
4. **卷**：持久化只用 **命名卷** + 显式 **`name:`**，避免匿名哈希卷；盖住镜像 **`VOLUME /opt/data`**。
5. **README**：步骤极简，**能一行命令就一行**；含 `setup`、`gateway setup`（按需）、`up`、`/health`。
6. **Windows / Docker Desktop**：TUI 文档写 **`docker exec -it hermes-agent … --tui`**，**不要默认 `-u hermes`**；纯 Linux 可自行加 `-u hermes`。

---

## 参考链接

- [Hermes Agent（Docker Hub）](https://hub.docker.com/r/nousresearch/hermes-agent)
- [TUI（简体中文）](https://hermes-agent.nousresearch.com/docs/zh-Hans/user-guide/tui)
- [API Server / OpenAI 兼容](https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server)
- 请求网关时：`Authorization: Bearer <与 .env 中 API_SERVER_KEY 相同>`
