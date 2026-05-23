# Iceberg REST Catalog for RustFS（Docker Compose）

本项目是 **Apache Iceberg REST Catalog 的定制配置**，专门用于配合 [RustFS](https://github.com/rustfs/rustfs)（S3 兼容存储）使用。

⚠️ **注意**：这不是标准的 Iceberg 部署。标准 Iceberg 支持多种元数据存储后端（JDBC、Hive、内存等）和多种底层存储（HDFS、S3、本地文件）。本配置固定使用 **S3FileIO + RustFS**。

## 与标准 Iceberg 的区别

| 特性 | 本配置 | 标准 Iceberg |
|------|--------|-------------|
| 元数据存储 | 无状态（元数据存于 S3） | JDBC、Hive、内存等 |
| 底层存储 | 固定 RustFS（S3 兼容） | HDFS、S3、本地文件等 |
| S3 实现 | 强制 S3FileIO | 可选 S3FileIO 或 Hadoop S3A |
| 用途 | 配合 Doris 查询 RustFS 上的 Iceberg 表 | 通用数据湖场景 |

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | `apache/iceberg-rest-fixture` |
| 端口 | 8181（REST API） |
| 数据卷 | 无（Catalog 为无状态服务，元数据存储于 S3） |
| 认证 | 通过 S3 Access Key / Secret Key 访问 RustFS |
| 健康检查 | 无内置 healthcheck，可通过 HTTP 请求验证 |
| 依赖 | 需要 RustFS（S3 兼容存储）已启动 |

## 部署

### 1. 环境变量

```bash
cp .env.example .env
```

编辑 `.env`，配置 RustFS 连接信息：

```env
AWS_ACCESS_KEY_ID=rustfsadmin
AWS_SECRET_ACCESS_KEY=rustfsadmin
CATALOG_S3_ENDPOINT=http://host.docker.internal:9000
```

### 2. 启动

```bash
docker compose up -d
```

### 3. 验证

**查看服务状态：**

```bash
docker compose ps
```

**测试 REST API：**

```bash
# PowerShell
Invoke-RestMethod -Uri http://localhost:8181/v1/config

# Bash
curl -s http://localhost:8181/v1/config
```

返回配置信息即表示服务正常。

**验证 S3 写入（创建 Namespace）：**

```bash
# PowerShell
Invoke-RestMethod -Uri http://localhost:8181/v1/namespaces -Method POST -Body '{"namespace":["test"]}' -ContentType 'application/json'

# Bash
curl -s -X POST http://localhost:8181/v1/namespaces -H 'Content-Type: application/json' -d '{"namespace":["test"]}'
```

预期返回（表示成功写入 S3）：
```json
{
  "namespace": ["test"],
  "properties": {
    "location": "s3://pb-bucket/test"
  }
}
```

## 与 Doris 集成

在 Doris 中创建 Iceberg Catalog 连接本服务：

```sql
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
```

## 日常使用

### 停止服务

```bash
docker compose down
```

### 查看日志

```bash
docker compose logs -f iceberg-rest
```

## 参考链接

- [Apache Iceberg 官方文档](https://iceberg.apache.org/docs/)
- [Iceberg REST Catalog 规范](https://iceberg.apache.org/docs/latest/configuration/)
- [Iceberg GitHub](https://github.com/apache/iceberg)
- [RustFS GitHub](https://github.com/rustfs/rustfs)
