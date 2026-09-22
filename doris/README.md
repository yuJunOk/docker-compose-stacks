# Doris（Docker Compose）

[Apache Doris](https://doris.apache.org/) 本机集群示例，MySQL 协议 **9030**。官方文档：[doris.apache.org/docs](https://doris.apache.org/docs/)。

---

## 两种编排

| 文件 | 拓扑 | 适用 |
|------|------|------|
| **`docker-compose.yml`**（默认） | 1 FE + **3 BE** | 默认 **3 副本**建表、Navicat 向导；内存建议 **≥ 8GB** |
| **`docker-compose.single.yml`** | 1 FE + **1 BE** | 省资源；建表须 **`replication_num = 1`** |

```bash
# 默认三 BE
docker compose up -d

# 单机备份编排
docker compose -f docker-compose.single.yml up -d
```

从旧版单 BE 的 **`docker compose.yml`** 迁到当前默认三 BE 时，先 **`down`**，再 **`up`**；卷名不同（`doris_be_storage` → `doris_be_storage_01`…），需 **`down -v`** 或自行迁数据。

---

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | `apache/doris:fe-2.1.11`、`apache/doris:be-2.1.11` |
| 端口 | **9030**（SQL）、**8030**（FE Web）；三 BE 时 BE HTTP **8040 / 8041 / 8042** |
| 数据卷 | `doris_fe_meta`；三 BE：`doris_be_storage_01`～`_03`；单机：`doris_be_storage` |
| 认证 | **root**，默认**无密码** |
| 客户端 | **MySQL** 驱动，`127.0.0.1:9030` |
| BE | 各 BE **`shm_size: "1gb"`** |

---

## 部署

### 1. 环境变量

```bash
cp .env.example .env
```

### 2. 启动

```bash
docker compose up -d
```

### 3. 验证

```bash
docker compose ps
```

**`doris_fe` 与全部 BE 为 `healthy` 后再连客户端**（三 BE 首启常需 **5～10 分钟**）。

```bash
docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -e "SELECT 1"
```

```bash
docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -e "SHOW BACKENDS\G"
```

三 BE 时应看到 **3 行**且 **Alive: true**。Web：http://localhost:8030

---

## 日常使用

### 设置 root 密码（可选）

认证在 **FE**，与 BE 个数无关；**`docker-compose.yml` / `docker-compose.single.yml` 用法相同**。将 `your_password` 换成你的密码：

```bash
docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -e "ALTER USER 'root'@'%' IDENTIFIED BY 'your_password';"
```

（使用单机编排时若未指定 `-f`，与启动时保持一致即可，例如 `-f docker-compose.single.yml`。）

### 建库建表

**默认三 BE**：可不写副本数（默认 3），或显式：

```sql
CREATE DATABASE IF NOT EXISTS mydb;
USE mydb;

CREATE TABLE user_log (
    user_id BIGINT,
    event_time DATETIME,
    event_type VARCHAR(50)
)
DUPLICATE KEY(user_id, event_time)
DISTRIBUTED BY HASH(user_id) BUCKETS 10
PROPERTIES ("replication_num" = "3");
```

**单机编排**（`docker-compose.single.yml`）必须：

```sql
PROPERTIES ("replication_num" = "1");
```

### 停止与删数据

```bash
docker compose down
```

```bash
docker compose down -v
```

`down -v` 删除对应编排下的全部命名卷，**不可恢复**。

---

## 资源建议

| 编排 | Docker 内存（建议） |
|------|---------------------|
| 三 BE（默认） | **≥ 8GB** |
| 单机 | **≥ 4GB**（紧张时 **6GB**） |

BE 不稳定可将 **`shm_size`** 改为 **`2gb`**。

---

## 参考链接

- [Apache Doris 文档](https://doris.apache.org/docs/)
- [Doris Docker Hub](https://hub.docker.com/r/apache/doris)

---

## 常见问题

### Backend / scanNode / `[10002: not alive]`

等 **`docker compose ps` 全部 healthy** 再连 Navicat；执行 **`SHOW BACKENDS\G`** 确认 **Alive: true**。三 BE 时应有 **3** 个存活 BE。

仍失败：`docker compose restart` 对应 BE，或 **`down -v` 后重装**（丢数据）。Navicat 连上后先 **`SELECT 1`**，勿立刻拉全库元数据。

### `replication num is 3, available backend num is 0`

- **三 BE 默认编排**：先确认 **`SHOW BACKENDS`** 有 **3** 个 **Alive**；不足 3 时等启动完成或查 `docker compose logs doris_be01` 等。
- **单机编排**：改用 **`docker-compose.single.yml`**，或建表 **`replication_num = 1`**。

### Doris 与 MySQL 客户端

- **9030** 为 Doris FE，非 MySQL；建库用 **`CREATE DATABASE`**，勿用带 MySQL 专用 DDL 的图形向导。
