# Langfuse + Doris（Docker Compose）

本目录提供 **单机 Docker Compose 栈**：**Langfuse**（Web + Worker）、分析后端 **Apache Doris**（FE + BE）、**PostgreSQL**、**Redis**、**MinIO**；适合联调、PoC，生产请改强密钥并做好备份。

**官方入口**：[Langfuse 文档](https://langfuse.com/docs) · [Langfuse（GitHub）](https://github.com/langfuse/langfuse) · [Apache Doris 文档](https://doris.apache.org/docs/getting-started/quick-start)。**镜像（Docker Hub）**：[selectdb/langfuse-web](https://hub.docker.com/r/selectdb/langfuse-web)、[selectdb/langfuse-worker](https://hub.docker.com/r/selectdb/langfuse-worker)、[apache/doris](https://hub.docker.com/r/apache/doris)、[postgres](https://hub.docker.com/_/postgres)、[redis](https://hub.docker.com/_/redis)、[minio/minio](https://hub.docker.com/r/minio/minio)。

**`.env`** 与 **`doris-config/jdbc_drivers/*.jar`** 已被 **`.gitignore`** 忽略（勿提交密钥与下载的驱动 jar）。下文命令均在与 **`docker-compose.yml` 同级** 目录执行。

**章节顺序**：**概览** → **部署**（环境变量、启动、验证、可选 Doris 密码、排障）→ **Doris**（图形客户端为可选）→ **日常使用** → **参考链接**。

---

## 概览

| 项目 | 说明 |
|------|------|
| 镜像（主要） | **`selectdb/langfuse-web`**、**`selectdb/langfuse-worker`** 默认 **`latest`**（生产请固定标签或 digest，避免长期漂移）；**`postgres:16-alpine`**、**`redis:7-alpine`**、**`minio/minio:RELEASE.…`**、**`apache/doris:fe-2.1.11` / `be-2.1.11`**（与 **`docker-compose.yml`** 一致） |
| 端口（默认映射） | Langfuse **3000** / Worker **3030**；Postgres **15432**；Redis **16379**；Doris **9030**（SQL）、**8030**（FE HTTP）；MinIO API **19090**、控制台 **19091**（见 **`.env`** 中 `LANGFUSE_*_HOST_PORT`） |
| 数据 / 卷 | **命名卷**：**`langfuse-doris_postgres_data`**、**`langfuse-doris_minio_data`**、**`langfuse-doris_doris_fe_meta`**、**`langfuse-doris_doris_be_storage`**（与 compose 中 `name:` 一致）；**Redis**：**`tmpfs /data`**，无持久化、重启清空；**勿**依赖匿名卷承载需要保留的数据 |
| 绑定挂载 | **`./doris-config/fe_custom.conf`**（只读）、**`./doris-config/jdbc_drivers`** → 容器内 JDBC 目录（见 **「Doris」**）；**`*.jar`** 已在 **`.gitignore`**，避免将驱动或内含凭据提交入库 |
| 认证 | 应用与中间件密钥见 **`.env`**（**`NEXTAUTH_SECRET`**、**`SALT`**、**`ENCRYPTION_KEY`**、**`POSTGRES_PASSWORD`**、**`REDIS_AUTH`**、**`MINIO_ROOT_*`** 等）；Doris **`root`** 默认空密码，可选设密见 **「部署」** |
| 健康检查 | 各服务均配置 **`healthcheck`**；**`docker compose ps` 中 `State` 为 `healthy`（或 `Up` 且无 `unhealthy`）即通过**；Doris 首启可能要 **数分钟** |
| 可视化 / 管理 | **Langfuse**：**`http://localhost:3000`**；**MinIO 控制台**：**`http://127.0.0.1:19091`**；**Doris FE HTTP**：**`http://127.0.0.1:8030`**（与 **9030** SQL 入口不同）；Doris SQL 可用 **MySQL 协议客户端**连 **9030**（见 **「Doris」**，属可选宿主机工具） |

Postgres 数据目录以 [官方镜像说明](https://hub.docker.com/_/postgres) 为准：**`/var/lib/postgresql/data`**。

---

## 部署

### 1. 环境变量

1. 安装并启动 **Docker Desktop**（或已带 Compose v2 的 Docker），确认 **`docker compose version`** 有输出。  
2. 进入本目录，复制环境文件（按系统任选其一）。

   Linux / macOS：

   ```bash
   cd langfuse-doris
   cp .env.example .env
   ```

   Windows（PowerShell）：

   ```powershell
   cd langfuse-doris
   Copy-Item .env.example .env
   ```

3. 编辑 **`.env`**，至少修改：**`NEXTAUTH_SECRET`**、**`SALT`**、**`ENCRYPTION_KEY`**、**`POSTGRES_PASSWORD`**、**`REDIS_AUTH`**、**`MINIO_ROOT_PASSWORD`**。  
   - **`DORIS_USER` / `DORIS_PASSWORD`** 可与模板一致（空密码），与 Doris 默认一致。  
   - 若 **`POSTGRES_PASSWORD`** 含 **`@`、`:`、空格** 等，须对 **`DATABASE_URL`** 内密码做 URL 编码，或改用不含这些字符的密码（与 [Postgres 连接串规则](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING) 一致）。  
   - Postgres 首次初始化时根据 **`POSTGRES_*`** 建库；**仅在有数据卷且已初始化过的数据目录上**改 **`POSTGRES_PASSWORD`** 不会自动改写库内密码，须按官方说明或删卷重建处理。

### 2. 启动

```bash
docker compose up -d
```

```bash
docker compose ps
```

待 **`doris_fe`**、**`doris_be`** 在 **`ps`** 中变为 **`healthy`**（首启可能要几分钟）后，再继续 **「验证」**。

### 3. 验证

**主路径（不要求宿主机安装 `psql` / `redis-cli` / `mysql`）**：在与 **`docker-compose.yml` 同级** 目录执行。

1. **进程与健康**（**`docker compose ps`** 的 **`STATUS`** 列出现 **`(healthy)`** 即通过；首启 Doris 可能要数分钟）：

   ```bash
   docker compose ps
   ```

   期望：**`langfuse-web`**、**`langfuse-worker`**、**`postgres`**、**`redis`**、**`minio`**、**`doris_fe`**、**`doris_be`** 均为 **`running`**，且 **`STATUS`** 中显示 **`(healthy)`**（compose 已配置 **`healthcheck`**）。

2. **PostgreSQL（容器内 `pg_isready`）**：

   ```bash
   docker compose exec postgres pg_isready -U postgres
   ```

3. **Redis（容器内 `redis-cli`，密码来自容器环境变量 `REDIS_AUTH`）**：

   ```bash
   docker compose exec redis sh -c 'redis-cli -a "$REDIS_AUTH" ping'
   ```

4. **MinIO（容器内 `mc`）**：

   ```bash
   docker compose exec minio mc ready local
   ```

5. **Doris（容器内 `mysql` 客户端，在 `doris_fe` 服务内连本机 9030）**：

   ```bash
   docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -e "SELECT 1;"
   ```

   若已为 **`root`** 设置密码，将 **`-pYourStrongPass`** 接在 **`-uroot`** 后（与 **`.env`** 中 **`DORIS_PASSWORD`** 一致）。

6. **Langfuse Web（容器内 `wget`，与 compose 中 `healthcheck` 一致）**：

   ```bash
   docker compose exec langfuse-web wget -q -O- http://127.0.0.1:3000/api/public/health
   ```

**（可选）宿主机浏览器**：打开 **`http://localhost:3000`**。

**（可选）宿主机 `curl`**（Windows 上 **`curl` 常为别名**，请用 **`curl.exe`**；丢弃响应体时用 **`NUL`**，与上表「Windows / Linux 差异」一致）：

Windows（PowerShell / CMD）：

```bash
curl.exe -s -o NUL -w "%{http_code}\n" http://localhost:3000/api/public/health
```

Linux / macOS：

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/public/health
```

返回 **`200`** 即通过。更多 Doris SQL 与 JDBC 见 **「Doris」**。

### 4.（可选）给 Doris `root` 设密码

**默认不必做**（**`.env`** 中 **`DORIS_PASSWORD`** 留空）。若要给 Doris 加密码：**先在 Doris 内执行改密 → 再改 `.env` → 再重启 Langfuse**（与改任意「数据库密码 + 应用配置」顺序一致）。语句以 [Doris · SET PASSWORD](https://doris.apache.org/docs/2.1/sql-manual/sql-statements/account-management/SET-PASSWORD/) 为准。

1. **`docker compose ps`** 中 **`doris_fe`** 为 **`Up` / `healthy`**。  
2. 改密（将 **`YourStrongPass`** 换成你的密码；密码含单引号请换密码或自行转义）：

   ```bash
   docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -e "SET PASSWORD = PASSWORD('YourStrongPass');"
   ```

3. 编辑 **`.env`**：**`DORIS_PASSWORD=YourStrongPass`**。  
4. 重启 Langfuse：

   ```bash
   docker compose up -d langfuse-web langfuse-worker
   ```

5. 校验：

   ```bash
   docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -pYourStrongPass -e "SELECT 1;"
   ```

**（可选）仅用临时容器连 Doris（不经 `docker compose exec`）**：例如本机 **`docker compose exec` 异常**、或习惯用 **`mysql:8` 交互式客户端** 时（**前提**：可拉取镜像；首次拉 **`mysql:8`** 会下载镜像）：

```powershell
docker run --rm -it mysql:8 mysql -h host.docker.internal -P 9030 -uroot
```

`host.docker.internal` 不可用则改为 **`127.0.0.1`**。

| 现象 | 处理 |
|------|------|
| **`ERROR 1045` / `using password: NO`（Langfuse 连 Doris）** | **`.env`** 与 Doris **`root`** 不一致；或宿主机存在空的 **`DORIS_PASSWORD`**。对齐后 **`docker compose up -d --force-recreate langfuse-web langfuse-worker`** |
| **`ERROR 1045`（仅 Doris 已设密）** | **`.env` 已写 `DORIS_PASSWORD`，但 Doris 内未 `SET PASSWORD`**（或两边不一致）——按本小节重做 |

### 5. 排障与说明

```bash
docker compose logs -f doris_be
```

```bash
docker compose logs -f doris_fe
```

```bash
docker compose logs -f langfuse-web
```

| 现象 | 处理 |
|------|------|
| **`doris_be` unhealthy / `dependency failed to start`** | **BE 尚未向 FE 注册**、**内存偏紧** 或健康检查过严；看 **`doris_be`** 日志中 **`ADD BACKEND`** / **`Alive`**；为本机 Docker 分配 **足够内存** |
| **首启慢** | 等待 **5～10 分钟** 后再 **`docker compose ps`** |

Doris FE 可选配置：**`./doris-config/fe_custom.conf`**（[FE 配置说明](https://doris.apache.org/docs/admin-manual/config/fe-config-template)）。

---

## Doris

**FE**：接客户端、解析 SQL、协调查询；**BE**：存数据、执行 fragment。**9030** 为 MySQL 协议 SQL 端口；**8030** 为 FE HTTP 运维页。

### 用 MySQL 客户端连接与建库

**（可选）宿主机已安装 DBeaver / DataGrip / MySQL Workbench 等**时：在 **`docker compose ps`** 中 **`doris_fe` / `doris_be` 已为 `healthy`** 后，新建连接类型选 **MySQL**，端口 **9030**（勿写成 **9300**）。

| 项 | 值 |
|----|-----|
| 主机 | **`127.0.0.1`** 或 **`localhost`** |
| 端口 | **`9030`** |
| 用户 | **`root`** |
| 密码 | 与 Doris **`root`** 及 **`.env`** 中 **`DORIS_PASSWORD`** 一致（默认可空） |

**不要用**「新建数据库」向导（易生成 **`DEFAULT CHARACTER SET utf8mb4`** 等 MySQL DDL，**Doris 不支持**）。在 **SQL 编辑器**中手写（库名与 **`.env`** 的 **`DORIS_DB`** 一致，多为 **`langfuse`**）：

```sql
CREATE DATABASE IF NOT EXISTS langfuse;
```

**DBeaver**：勿使用 **`SHOW BACKENDS\G`**（**`\G`** 仅 **`mysql` 命令行** 识别）；使用 **`SHOW BACKENDS;`**。少展开「索引 / 存储过程 / 触发器 / 事件」——Doris **不等同于 MySQL**，易触发不适用查询或 **`no scanNode`**。

### Catalog 与 JDBC 驱动目录 `doris-config/jdbc_drivers`

#### Catalog 是什么

**Catalog** 为 Doris 对外部数据源的登记（如 **JDBC 连本 compose 内的 PostgreSQL**）。**FE** 做元数据与校验，**实际 JDBC 在 BE 上执行**。

#### 宿主机目录与挂载

| 项 | 说明 |
|----|------|
| 宿主机路径 | 与 **`docker-compose.yml` 同目录**下的 **`doris-config/jdbc_drivers/`**（目录名 **`jdbc_drivers`**，下划线） |
| 容器内路径 | **`/opt/apache-doris/fe/jdbc_drivers/`**（**`doris_fe` / `doris_be` 均挂载**；缺 BE 挂载会出现 **Test BE Connection to JDBC Failed**） |
| 版本控制 | **`.gitignore`** 已包含 **`doris-config/jdbc_drivers/*.jar`**：目录可入库，**下载的 jar 勿提交** |
| 网络 | **FE、BE** 均在 **`default`** 网，JDBC 才能访问 **`langfuse-postgres:5432`**；**`doris_internal`** 用于 FE–BE 固定 IP（**172.30.0.2 / 172.30.0.3**） |

#### 准备 PostgreSQL JDBC 的 jar

**`CREATE CATALOG`** 中 **`driver_url`** 的文件名须与目录内 **真实文件名** 一致。

```bash
mkdir -p doris-config/jdbc_drivers
curl -fsSL -o doris-config/jdbc_drivers/postgresql-42.5.1.jar "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.5.1/postgresql-42.5.1.jar"
```

PowerShell：

```powershell
New-Item -ItemType Directory -Force -Path "doris-config\jdbc_drivers" | Out-Null
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.5.1/postgresql-42.5.1.jar" -OutFile "doris-config\jdbc_drivers\postgresql-42.5.1.jar"
```

#### 修改挂载或首次放 jar 之后

**仅 `docker restart` 不会应用 compose 新增的 volume。** 须执行：

```bash
docker compose up -d --force-recreate doris_fe doris_be
```

#### 校验

```bash
docker compose exec doris_fe ls -la /opt/apache-doris/fe/jdbc_drivers/
```

```bash
docker compose exec doris_be ls -la /opt/apache-doris/fe/jdbc_drivers/
```

```bash
docker compose exec doris_fe getent hosts langfuse-postgres
```

**（可选）宿主机已安装 Docker CLI**：查看绑定挂载在宿主机上的 **`Source`**：

```bash
docker inspect doris_fe --format "{{json .Mounts}}"
```

在输出中查找 **`Destination` 含 `jdbc_drivers`** 的 **`Source`**，确认与 **`doris-config/jdbc_drivers`** 一致且含对应 **`.jar`**。

#### 测试用 SQL（库名、密码按 `.env` 修改）

在 **9030** 执行：

```sql
DROP CATALOG IF EXISTS pg_test;
CREATE CATALOG pg_test PROPERTIES (
    "type" = "jdbc",
    "user" = "postgres",
    "password" = "postgres",
    "jdbc_url" = "jdbc:postgresql://langfuse-postgres:5432/postgres",
    "driver_url" = "file:///opt/apache-doris/fe/jdbc_drivers/postgresql-42.5.1.jar",
    "driver_class" = "org.postgresql.Driver"
);
SHOW CATALOGS;
SHOW CREATE CATALOG pg_test;
```

#### 常见问题

| 现象 | 处理 |
|------|------|
| **`Caused by: langfuse-postgres` / JDBC 连不上** | 确认 **FE、BE** 均在 **`default`**；**`jdbc_url`** 主机 **`langfuse-postgres`**、端口 **5432**（容器内，非 **15432**） |
| **缺 jar / `No such file or directory`** | **`driver_url` 文件名** 与 **`doris-config/jdbc_drivers/`** 一致；已 **`--force-recreate doris_fe doris_be`** |
| **`Test BE Connection to JDBC Failed`** | BE 容器内同路径须有 jar；对齐 compose 后 **`--force-recreate doris_be`** |
| **`no scanNode` / blacklist** | 多为 **BE 刚重启**；等 **healthy** 后重连 DBeaver；少展开不适用节点 |

临时拷贝（不推荐长期使用；绑定挂载时文件会出现在宿主机 **`doris-config/jdbc_drivers/`**，Linux 上可能为 **root** 属主）：

```bash
docker compose cp postgresql-42.5.1.jar doris_fe:/opt/apache-doris/fe/jdbc_drivers/
```

---

## 日常使用

### 备份

本栈**未内置**自动备份。需要保留数据时，请自行对 **命名卷** 做卷级备份，或对 Postgres 使用 **`docker compose exec postgres` + `pg_dump`** 等到安全位置；MinIO、Doris 卷同理按官方/运维习惯处理。

### 停止（保留数据）

```bash
docker compose down
```

### 删除持久化数据（不可恢复）

```bash
docker volume rm langfuse-doris_postgres_data langfuse-doris_minio_data langfuse-doris_doris_fe_meta langfuse-doris_doris_be_storage
```

若曾用旧 compose 把 Postgres 挂在 **`/var/lib/postgresql`**，可能残留匿名卷；当前数据目录为 **`/var/lib/postgresql/data`**。升级后若库为空，需 **`pg_dump` / 迁卷** 或删卷重建。

**安全**：compose 将若干端口绑定 **`127.0.0.1`**，降低被局域网误访问的风险；若改为 **`0.0.0.0`**，请结合防火墙与认证评估暴露面。

---

## 参考链接

- [Langfuse 文档](https://langfuse.com/docs) · [Langfuse（GitHub）](https://github.com/langfuse/langfuse)
- [selectdb/langfuse-web（Docker Hub）](https://hub.docker.com/r/selectdb/langfuse-web) · [selectdb/langfuse-worker（Docker Hub）](https://hub.docker.com/r/selectdb/langfuse-worker)
- [apache/doris（Docker Hub）](https://hub.docker.com/r/apache/doris)
- [PostgreSQL 官方 Docker Hub](https://hub.docker.com/_/postgres)
- [Redis 官方 Docker Hub](https://hub.docker.com/_/redis)
- [MinIO Docker Hub](https://hub.docker.com/r/minio/minio)
- [Apache Doris 文档](https://doris.apache.org/docs/getting-started/quick-start)
- [Doris · SET PASSWORD](https://doris.apache.org/docs/2.1/sql-manual/sql-statements/account-management/SET-PASSWORD/)
