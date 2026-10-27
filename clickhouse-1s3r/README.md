# ClickHouse 1s3r（1 分片 × 3 副本 + ZooKeeper）

本机 / 内网联调用的 **单分片三副本** 集群：3 个 ClickHouse + 3 个 ZooKeeper。集群名 **`cluster_1s3r`**（见 `config/config.d/cluster.xml`）。官方镜像：[clickhouse-server](https://hub.docker.com/r/clickhouse/clickhouse-server)、[zookeeper](https://hub.docker.com/_/zookeeper)。

与本仓库 **[clickhouse](../clickhouse/)**（单节点）互补；同机时注意原生端口不要与单机栈的 **19000** / RustFS **9000** 冲突（本编排默认宿主机 **19001–19003**）。

---

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | **`CLICKHOUSE_IMAGE`**（默认 **`clickhouse/clickhouse-server:24.8`**）；**`ZOOKEEPER_IMAGE`**（默认 **`zookeeper:3.9`**） |
| 拓扑 | 1 shard × 3 replicas；协调 **ZooKeeper** 三节点 |
| 端口 | 节点 1–3 HTTP 默认 **18124–18126**；原生 **19001–19003** → 容器 **9000**；ZK 客户端 **2181–2183** |
| 绑定 | **`CLICKHOUSE_BIND`**（默认 **`127.0.0.1`**） |
| 数据卷 | 每节点 `clickhouse_1s3r_nodeN_data` / `_logs`；每 ZK `clickhouse_1s3r_zkN_data` / `_datalog` |
| 配置 | 公共 `config/config.d/` + 各节点 `config/nodeN/config.d/macros.xml`（相对路径挂载） |
| 认证 | **`.env`** 中 **`CLICKHOUSE_PASSWORD`**（必填） |
| 健康检查 | Compose **`healthcheck`**；**`docker compose ps` 均为 `healthy`** 即就绪 |
| 可视化 / 管理 | 无随镜像完整 Web；可用 **DBeaver** / **clickhouse-client** 连任一节点端口 |

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

编辑 **`.env`**：将 **`CLICKHOUSE_PASSWORD`** 改为强密码；按需改端口与绑定。

### 2. 启动

```bash
docker compose up -d
```

首次需等 ZooKeeper 与三节点 ClickHouse 依次就绪，可能 **1–2 分钟**。

### 3. 验证

```bash
docker compose ps
```

六个服务均为 **`healthy`** 即通过。

```bash
docker compose exec clickhouse-node1 clickhouse-client --query "SELECT version()"
```

```bash
docker compose exec clickhouse-node1 clickhouse-client --query "SELECT * FROM system.clusters WHERE cluster = 'cluster_1s3r'"
```

应看到 **3** 行副本（host 为 `clickhouse-node1` … `node3`）。

**（可选）建复制表示例**（在任意节点执行；`ON CLUSTER` 会落到三副本）：

```bash
docker compose exec clickhouse-node1 clickhouse-client -q "
CREATE DATABASE IF NOT EXISTS demo ON CLUSTER cluster_1s3r;
CREATE TABLE IF NOT EXISTS demo.events ON CLUSTER cluster_1s3r (
  id UInt64,
  event_time DateTime,
  name String
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/demo/events', '{replica}')
ORDER BY (event_time, id);
"
```

```bash
docker compose exec clickhouse-node1 clickhouse-client --query "SELECT hostname(), count() FROM system.replicas WHERE table = 'events'"
```

**（可选）HTTP**：

```bash
curl -s "http://127.0.0.1:18124/ping"
```

Windows（PowerShell）：

```powershell
curl.exe -s "http://127.0.0.1:18124/ping"
```

应返回 `Ok.`。

---

## 日常使用

### 连接串

| 节点 | HTTP | 原生（宿主机） |
|------|------|----------------|
| node1 | `http://127.0.0.1:18124` | `127.0.0.1:19001` |
| node2 | `http://127.0.0.1:18125` | `127.0.0.1:19002` |
| node3 | `http://127.0.0.1:18126` | `127.0.0.1:19003` |

用户名默认 **`default`**，密码以 **`.env`** 为准。容器内节点互访用服务名与官方端口（**9000** / **8123**）。

### 停止与删卷

```bash
docker compose down
```

```bash
docker compose down -v
```

`down -v` 会删除全部 CH / ZK 命名卷，**不可恢复**。

---

## 绑定到所有网卡（0.0.0.0）

将 **`.env`** 中 **`CLICKHOUSE_BIND=0.0.0.0`** 后重新 `up`。公网暴露时务必 **防火墙限制来源** 或使用 **SSH 隧道 / VPN**。

---

## 参考链接

- [ClickHouse 复制](https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replication)
- [clickhouse/clickhouse-server（Docker Hub）](https://hub.docker.com/r/clickhouse/clickhouse-server)
- [ZooKeeper（Docker Hub）](https://hub.docker.com/_/zookeeper)
- 本仓库单机栈：[clickhouse](../clickhouse/)
