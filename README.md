# Docker Compose Stacks

一组可独立使用的 **Docker Compose** 编排示例：每个子目录自带 `docker-compose.yml`、`.env.example` 与分步 **README**，面向本机开发、内网联调与 PoC。默认强调 **命名卷**（避免匿名持久化卷）、**明确镜像标签**、以及 **Windows / Linux** 均可执行的验证步骤。

> 各栈镜像、端口与密钥策略不同；**生产环境**请自行加固网络、备份与密钥管理。本仓库配置与文档为示例，不替代上游产品的安全与运维指南。

---

## 目录

| 目录 | 说明 |
|------|------|
| [redis](./redis/) | 单机 Redis 7（Alpine），密码认证，命名卷 |
| [pgsql-standalone](./pgsql-standalone/) | 单机 PostgreSQL 16（Alpine），命名卷 |
| [rustfs](./rustfs/) | 单机 [RustFS](https://github.com/rustfs/rustfs)（S3 兼容），Web 控制台 |
| [hermes-agent](./hermes-agent/) | [Hermes Agent](https://github.com/EKKOLearnAI/hermes-agent) 网关 + Dashboard |
| [langfuse-doris](./langfuse-doris/) | Langfuse + Apache Doris + Postgres + Redis + MinIO 联调栈 |

子目录 **README** 含概览表、部署、验证与参考链接；请进入对应目录按文档操作。

---

## 前置条件

- [Docker](https://docs.docker.com/get-docker/) 与 **Compose V2**（`docker compose`，非旧版 `docker-compose` 独立二进制）
- 能拉取各 `docker-compose.yml` 中声明的镜像（部分需访问 Docker Hub 或第三方 registry）

检查：

```bash
docker compose version
```

---

## 快速开始

1. 进入目标子目录，例如：

   ```bash
   cd redis
   ```

2. 复制环境变量模板并编辑（**至少修改密码/密钥**）：

   ```bash
   cp .env.example .env
   ```

   Windows（PowerShell）：

   ```powershell
   Copy-Item .env.example .env
   ```

3. 阅读该目录 **README**，按「环境变量 → 启动 → 验证」顺序执行，典型启动命令：

   ```bash
   docker compose up -d
   ```

4. 验证优先使用 **`docker compose exec <服务名> …`**，避免依赖宿主机是否安装 `redis-cli`、`psql` 等（详见各子目录 README）。

---

## 仓库约定

新增或修订子项目文档时，请遵循 [docker-compose-readme-guidelines.md](./docker-compose-readme-guidelines.md)（卷命名、官方文档对齐、跨平台验证写法等）。

---

## 安全提示

- **勿提交** `.env`、数据目录、下载的 JDBC 驱动等；各子目录 `.gitignore` 已做基础忽略，提交前请 `git status` 确认。
- 默认端口多绑定 **本机**（如 `127.0.0.1`）；若改为 `0.0.0.0` 暴露到局域网或公网，须配合防火墙与强密码。
- 删除命名卷或数据目录为 **不可逆** 操作，各 README 中会单独说明。

---

## 许可证

本仓库中的 Compose 文件、文档与辅助配置以 **[MIT License](./LICENSE)** 发布。

各子目录所拉取的 **容器镜像** 受其各自上游许可证约束（如 PostgreSQL、Redis、Langfuse、Doris 等），使用与再分发时请遵守对应项目条款。

---

## 参考

- [Docker Compose 文档](https://docs.docker.com/compose/)
- 子项目 README 内的 Docker Hub / 官方文档 / GitHub 链接
