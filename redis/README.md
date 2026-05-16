# Redis（Docker Compose）

本目录提供一份 **Docker Compose** 示例：单机 **Redis 7**（Alpine），带密码；用户名默认 **`default`**，可按需改为 ACL 专用用户。

---

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | **`redis:7-alpine`** |
| 数据 | 命名卷 **`redis_data`**（固定名，无匿名哈希卷）→ 容器 **`/data`**；默认未配置 AOF/RDB，**键仍在内存**，重启后业务数据仍会丢；要持久化请自行加 **`redis.conf` / `appendonly` 等** |
| 容器端口 | **6379** |
| 宿主机端口 | **`.env`** 中 **`REDIS_HOST_PORT`**（默认 **6379**） |
| 监听地址 | 默认 **`REDIS_BIND=127.0.0.1`**，仅本机；改为 **`0.0.0.0`** 则暴露到所有网卡（须防火墙） |
| 认证 | **`REDIS_PASSWORD`** 必填；**`REDIS_USERNAME`** 默认 **`default`**（非 `default` 时走 ACL，并关闭内置 `default` 用户） |
| 健康检查 | Compose **`healthcheck`**（`redis-cli` + `PING`） |
| 可视化 / 管理界面 | **无**（Redis 本身不提供随镜像自带的 Web 管理页）；可用 **Redis Insight**、**Another Redis Desktop Manager**、**DBeaver** 等连本机端口与密码验证 |

---

## 部署

建议顺序：**环境变量 → 后台启动 → 验证**。

### 1. 环境变量

镜像版本在 **`docker-compose.yml` 的 `image:`**（当前 **`redis:7-alpine`**）；**`.env`** 只放 **`REDIS_*`** 等（**`.gitignore`** 已忽略 **`.env`**）。

若尚无 **`.env`**：

```bash
cd redis
cp .env.example .env
```

PowerShell（在 **`redis` 目录**）：

```powershell
Copy-Item .env.example .env
```

编辑 **`.env`**：

- **`REDIS_PASSWORD`**：改为强密码（必填）。未设置时 **`docker compose config`** 会报错，属预期。
- **`REDIS_USERNAME`**：保持 **`default`** 即可；若改为自定义名，客户端需带 **`--user`**（见下）。
- **`REDIS_HOST_PORT`**：若本机已有其它 Redis 占用 **6379**，改为空闲端口。

### 2. 后台启动

```bash
docker compose up -d
```

### 3. 验证

```bash
docker compose ps
```

**判断是否装好**：容器 **State** 为 **`healthy`**（健康检查通过；首次就绪约数秒）。

**主路径（不要求宿主机安装 `redis-cli`）**，在 **`docker-compose.yml` 所在目录**执行：

```bash
docker compose exec redis sh -c 'if [ "$REDIS_USERNAME" = "default" ]; then redis-cli -a "$REDIS_PASSWORD" ping; else redis-cli --user "$REDIS_USERNAME" -a "$REDIS_PASSWORD" ping; fi'
```

返回 **`PONG`** 即服务可用。

**（可选）宿主机已安装 `redis-cli` 时**，可从本机连映射端口（**`-p`** 与 **`.env`** 中 **`REDIS_HOST_PORT`** 一致；勿把占位符当作字面量复制）：

```bash
redis-cli -h 127.0.0.1 -p 6379 -a "<从 .env 读取的 REDIS_PASSWORD>" ping
```

自定义 **`REDIS_USERNAME`** 时再加 **`--user`**，用户名与密码均来自 **`.env`**。

**用图形客户端**（任选其一安装在本机）：**主机 `127.0.0.1`**、**端口 `REDIS_HOST_PORT`**（默认 **6379**）、**密码 `REDIS_PASSWORD`**；用户名非 **`default`** 时在工具里填写 **`REDIS_USERNAME`**。常见客户端：[Redis Insight](https://redis.io/insight/)（官方）、[Another Redis Desktop Manager](https://github.com/qishibo/AnotherRedisDesktopManager)、DBeaver 等。

## 日常使用

### 仅本机访问（推荐开发机）

默认已在 **`docker-compose.yml`** 中使用 **`127.0.0.1`**（通过 **`REDIS_BIND`**，见 **`.env.example`**）。若需局域网访问，在 **`.env`** 中将 **`REDIS_BIND`** 设为 **`0.0.0.0`** 并自行加固网络。

### 自定义用户名与密码中的特殊字符

**`REDIS_USERNAME` ≠ `default`** 时，启动脚本会把密码拼进 **`redis-server --user …`**；密码中请勿使用未转义的 **`"`**、**`` ` ``** 等 shell 敏感字符，以免启动失败。

### 停止与数据

```bash
docker compose down
```

命名卷 **`redis_data`** 会保留（数据目录在 **`/data`**，默认仍不保证键级持久化）。若要连卷一起删：

```bash
docker compose down -v
# 或：docker volume rm redis_data
```

### 进容器排查

```bash
docker compose exec redis sh
# 容器内（需带密码）：
# redis-cli -a "$REDIS_PASSWORD" ping
```

---

## 参考链接

- [Redis 官方 Docker Hub](https://hub.docker.com/_/redis)
- [Redis 文档](https://redis.io/docs/)
- [Redis（GitHub）](https://github.com/redis/redis)
