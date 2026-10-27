# PostgreSQL（单机 Docker Compose）

本目录结构与 **`hermes-agent`** 对齐：根目录 **`docker-compose.yml`**、**`.env.example`**、**`.gitignore`**（忽略 **`.env`**），便于本机或内网单机跑一份持久化 Postgres。

---

## 概览

| 项目 | 说明 |
|------|------|
| 数据 | 命名卷 **`pgsql-data`** → 容器内 **`/var/lib/postgresql/data`** |
| 端口 | 宿主机 **`PG_PORT`**（默认 **5432**）→ 容器 **5432** |
| 镜像 | **`POSTGRES_IMAGE`**（默认 **`postgres:16-alpine`**） |
| 认证 | **`.env`** 中 **`POSTGRES_PASSWORD`**（必填）；**`POSTGRES_USER`** / **`POSTGRES_DB`** 可配 |
| 健康检查 | Compose **`healthcheck`**（`pg_isready`）；**`docker compose ps` 为 `healthy`** 即就绪（首启约数秒） |
| 可视化 / 管理 | **无**随镜像自带的 Web；可用 **DBeaver**、**pgAdmin**、**DataGrip** 等连 **`127.0.0.1:<PG_PORT>`** |

---

## 部署

### 1. 复制并编辑环境变量

```bash
cp .env.example .env
```

PowerShell：

```powershell
Copy-Item .env.example .env
```

编辑 **`.env`**：将 **`POSTGRES_PASSWORD`** 改为强密码；按需改 **`POSTGRES_USER`**、**`POSTGRES_DB`**、**`PG_PORT`**。

**注意**：`POSTGRES_*` 仅在 **首次创建数据卷** 时用于初始化；卷里已有数据时改环境变量不会自动改库内密码，需按 [官方文档](https://hub.docker.com/_/postgres) 自行迁移或删卷重建（会丢数据）。

### 2. 启动

```bash
docker compose up -d
```

### 3. 验证

```bash
docker compose ps
```

**`postgres`** 状态为 **`healthy`** 即健康检查通过（首次可能要 **`start_period`** 内若干秒）。

```bash
docker compose exec postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

```bash
docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select version();"'
```

**（可选）宿主机已安装 `psql` 时**，可从本机直连（用户名 / 库名 / 密码以 **`.env`** 为准，勿在文档中粘贴真实密码）：

```bash
psql "postgresql://postgres:<你的密码>@127.0.0.1:<PG_PORT>/postgres"
```

将 **`<你的密码>`**、**`<PG_PORT>`** 换成你在 **`.env`** 中的值；默认 **`PG_PORT`** 为 **5432**。

## 绑定到所有网卡（0.0.0.0）

默认 **`ports`** 写成 **`"5432:5432"`** 时，Docker 会把宿主机 **所有接口** 上的该端口映射出去（等价于 `0.0.0.0:5432`）。若机器暴露在公网，务必 **防火墙限制来源 IP** 或使用 **SSH 隧道 / VPN**，勿裸奔数据库端口。

若只想本机访问，可将 **`docker-compose.yml`** 中端口改为 **`127.0.0.1:${PG_PORT:-5432}:5432`**。

---

## 停止与删卷（清空数据）

```bash
docker compose down
docker volume rm pgsql-data
```

第二行会删除持久化数据，请谨慎执行。

---

## 参考

- [PostgreSQL 官方文档](https://www.postgresql.org/docs/)
- [PostgreSQL 官方 Docker Hub](https://hub.docker.com/_/postgres)
