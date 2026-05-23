# Doris（Docker Compose）

[Apache Doris](https://doris.apache.org/) 是一个高性能的分析型数据库，支持标准 SQL 和多种数据源联邦查询。

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | `apache/doris:fe-2.1.11`、`apache/doris:be-2.1.11` |
| 端口 | 8030(FE HTTP)、9030(FE MySQL)、9010(FE内部)、8040(BE HTTP)、9050/9060(BE内部) |
| 数据卷 | `doris_fe_meta`（FE 元数据）、`doris_be_storage`（BE 存储） |
| 认证 | root 用户，**默认无密码**，首次启动后需手动设置 |
| 健康检查 | FE: `SELECT 1`；BE: `SHOW BACKENDS` 检查 Alive 状态 |
| 管理界面 | http://localhost:8030 |

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

**查看服务状态（等待 healthy）：**

```bash
docker compose ps
```

**容器内连接测试：**

```bash
# FE 健康检查
docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -e 'SELECT 1'

# BE 健康检查
docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -e 'SHOW BACKENDS'
```

**Web UI：**
- 地址：http://localhost:8030

**宿主机连接（需安装 mysql 客户端）：**

```bash
mysql -h 127.0.0.1 -P 9030 -u root
```

## 设置 root 密码

Doris 官方镜像不支持通过环境变量自动设置密码，首次启动后需手动设置：

```bash
# 进入 FE 容器设置密码
docker compose exec doris_fe mysql -h 127.0.0.1 -P 9030 -uroot -e "ALTER USER 'root'@'%' IDENTIFIED BY 'your_password';"
```

设置密码后，后续连接需使用密码：

```bash
# 命令行连接（带密码）
mysql -h 127.0.0.1 -P 9030 -u root -p

# Navicat/DBeaver 连接
# 主机: localhost, 端口: 9030, 用户名: root, 密码: your_password
```

## 日常使用

### 创建 Doris 内部表

```sql
-- 创建数据库
CREATE DATABASE IF NOT EXISTS mydb;
USE mydb;

-- 创建表
CREATE TABLE user_log (
    user_id BIGINT,
    event_time DATETIME,
    event_type VARCHAR(50)
)
DUPLICATE KEY(user_id, event_time)
DISTRIBUTED BY HASH(user_id) BUCKETS 10
PROPERTIES ("replication_num" = "1");
```

### 创建 Iceberg Catalog（连接外部数据源）

```sql
-- 创建 Iceberg Catalog 连接 RustFS
CREATE CATALOG iceberg_rustfs PROPERTIES (
    'type' = 'iceberg',
    'iceberg.catalog.type' = 'rest',
    'iceberg.catalog.uri' = 'http://iceberg-rest:8181',
    's3.endpoint' = 'http://rustfs:9000',
    's3.access_key' = 'rustfsadmin',
    's3.secret_key' = 'rustfsadmin',
    's3.region' = 'us-east-1',
    's3.path.style.access' = 'true'
);

-- 使用 Catalog
USE iceberg_rustfs;
SHOW DATABASES;
```

## 停止与清理

```bash
# 停止服务
docker compose down

# 停止并删除数据卷（数据将丢失）
docker compose down -v
```

⚠️ **警告**：`down -v` 会删除命名卷 `doris_fe_meta` 和 `doris_be_storage`，所有数据将丢失。

## 资源需求

- **内存**：至少 4GB（FE 2GB + BE 2GB）
- **磁盘**：根据数据量调整

## 参考链接

- [Apache Doris 官方文档](https://doris.apache.org/docs/)
- [Doris Docker Hub](https://hub.docker.com/r/apache/doris)
- [Doris GitHub](https://github.com/apache/doris)
