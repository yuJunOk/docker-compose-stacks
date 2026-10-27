# ClickHouse（单机 Docker Compose）

[ClickHouse](https://clickhouse.com/) 本机单节点示例：HTTP **8123**、原生协议宿主机 **19000**（容器内仍为 **9000**）。官方镜像说明：[Docker Hub](https://hub.docker.com/r/clickhouse/clickhouse-server)。

与本仓库 **[rustfs](../rustfs/)** 同机时：RustFS S3 API 官方默认占宿主机 **9000**，故本编排把 ClickHouse 原生端口映射到 **19000**（与 [官方 Docker 示例](https://hub.docker.com/r/clickhouse/clickhouse-server) 常见写法一致）。

---

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | **`CLICKHOUSE_IMAGE`**（默认 **`clickhouse/clickhouse-server:24.8`**） |
| 端口 | HTTP **`CLICKHOUSE_HTTP_PORT`**（默认 **8123**）；原生 **`CLICKHOUSE_NATIVE_PORT`**（默认 **19000** → 容器 **9000**） |
| 绑定 | **`CLICKHOUSE_BIND`**（默认 **`127.0.0.1`**，仅本机） |
| 数据卷 | **`clickhouse_data`** → `/var/lib/clickhouse`；**`clickhouse_logs`** → `/var/log/clickhouse-server` |
| 认证 | **`.env`** 中 **`CLICKHOUSE_PASSWORD`**（必填）；**`CLICKHOUSE_USER`** / **`CLICKHOUSE_DB`** 可配 |
| 健康检查 | Compose **`healthcheck`**（`clickhouse-client`）；**`docker compose ps` 为 `healthy`** 即就绪 |
| 可视化 / 管理 | 无随镜像自带的完整 Web 控制台；可用 **DBeaver**、**DataGrip**、**clickhouse-client** 等连本机端口；HTTP 可用 `curl` 查 `/ping` |

---

## 部署

### 1. 环境变量

```bash
cp .env.example .env
```

PowerShell：

```powershell
Copy-Item .env.example .env
```

编辑 **`.env`**：将 **`CLICKHOUSE_PASSWORD`** 改为强密码；按需改用户、库名、端口。

未设置密码时，官方镜像会**禁用 `default` 用户的网络访问**（仅容器内本地可用）。本编排要求必须设置密码。

### 2. 启动

```bash
docker compose up -d
```

### 3. 验证

```bash
docker compose ps
```

**`clickhouse`** 状态为 **`healthy`** 即通过（首次可能需数十秒）。

```bash
docker compose exec clickhouse clickhouse-client --query "SELECT version()"
```

```bash
docker compose exec clickhouse clickhouse-client --query "SELECT 1"
```

**（可选）HTTP**：

Linux / macOS：

```bash
curl -s "http://127.0.0.1:8123/ping"
```

Windows（PowerShell，用 **`curl.exe`**）：

```powershell
curl.exe -s "http://127.0.0.1:8123/ping"
```

应返回 `Ok.`。带密码查询示例（将密码换成 `.env` 中的值）：

```bash
echo 'SELECT version()' | curl -s "http://127.0.0.1:8123/?user=default&password=<你的密码>" --data-binary @-
```

---

## 日常使用

### 连接串示例

| 协议 | 说明 |
|------|------|
| HTTP | `http://127.0.0.1:8123` |
| 原生 | `127.0.0.1:19000`（宿主机；容器内仍为 **9000**） |

用户名默认 **`default`**，密码与库名以 **`.env`** 为准。

### 简易建库建表

```bash
docker compose exec clickhouse clickhouse-client -q "
CREATE DATABASE IF NOT EXISTS demo;
CREATE TABLE IF NOT EXISTS demo.events (
  id UInt64,
  event_time DateTime,
  name String
) ENGINE = MergeTree
ORDER BY (event_time, id);
"
```

### 停止与删卷

```bash
docker compose down
```

```bash
docker compose down -v
```

`down -v` 会删除 **`clickhouse_data`** / **`clickhouse_logs`**，**不可恢复**。

---

## 绑定到所有网卡（0.0.0.0）

将 **`.env`** 中 **`CLICKHOUSE_BIND=0.0.0.0`** 后重新 `up`。若机器暴露在公网，务必 **防火墙限制来源** 或使用 **SSH 隧道 / VPN**，勿裸奔数据库端口。

---

## 参考链接

- [ClickHouse 文档](https://clickhouse.com/docs)
- [clickhouse/clickhouse-server（Docker Hub）](https://hub.docker.com/r/clickhouse/clickhouse-server)
- [官方镜像 README](https://github.com/ClickHouse/ClickHouse/blob/master/docker/server/README.md)
