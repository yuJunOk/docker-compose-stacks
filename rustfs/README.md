# RustFS（Docker Compose）

本目录提供一份 **Docker Compose** 示例：单机 **[RustFS](https://github.com/rustfs/rustfs)**（S3 兼容对象存储），数据目录由 **`.env`** 中 **`RUSTFS_DATA_DIR`** 指定（默认 **`./rustfs_data`**）。

---

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | **`rustfs/rustfs:latest`**（**`latest` 有漂移风险**，生产请固定标签或 digest）；[Docker Hub](https://hub.docker.com/r/rustfs/rustfs)、[GitHub](https://github.com/rustfs/rustfs) |
| 数据 | **`.env`** 中 **`RUSTFS_DATA_DIR`**（默认 **`./rustfs_data`**）→ 容器 **`/data`**；目录不存在时 Docker 会创建；**`.gitignore`** 已忽略默认数据目录 |
| S3 API | 容器 **9000**；宿主机 **`RUSTFS_PORT_9000`**（默认 **9000**） |
| 控制台（网页） | 容器 **9001**；宿主机 **`RUSTFS_PORT_9001`**（默认 **9001**）→ 浏览器 **Web 管理界面**，用访问密钥登录 |
| 访问密钥 | **`.env`** 中 **`RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`** 注入容器（默认 **`rustfsadmin`**） |
| 健康检查 | 本 compose **未**配置 **`healthcheck`**；以 **`docker compose ps`** 为 **`running`** + 控制台或下方 **curl** 为准 |
| 监听地址 | 默认 **`RUSTFS_BIND=127.0.0.1`**，仅本机可访问映射端口；改为 **`0.0.0.0`** 则监听所有网卡（须配合防火墙） |

---

## 部署

建议顺序：**环境变量 → 后台启动 → 验证**。

### 1. 环境变量

镜像版本在 **`docker-compose.yml` 的 `image:`**；**`.env`** 放 **`RUSTFS_*`**：数据目录、绑定端口、访问密钥等（**`.gitignore`** 已忽略 **`.env`**）。

若尚无 **`.env`**：

```bash
cd rustfs
cp .env.example .env
```

PowerShell（在 **`rustfs` 目录**）：

```powershell
Copy-Item .env.example .env
```

按需修改 **`RUSTFS_DATA_DIR`**（例如换大盘 **`D:/data/rustfs`**，Windows 建议正斜杠）、**`RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`**；若 **9000 / 9001** 被占用，调整 **`RUSTFS_PORT_9000` / `RUSTFS_PORT_9001`**。

### 2. 后台启动

```bash
docker compose up -d
```

### 3. 验证

```bash
docker compose ps
```

**判断是否装好**：容器为 **`running`**；下面任选其一即可。

1. **可视化网页（推荐）**：浏览器打开 **`http://127.0.0.1:<RUSTFS_PORT_9001>`**（默认 **`http://127.0.0.1:9001`**，端口以 **`.env`** 为准）。使用 **`.env`** 中的 **`RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY`**（默认 **`rustfsadmin` / `rustfsadmin`**）登录，能进入控制台即说明 **9001** 与认证正常。

2. **S3 API 端口探测**：匿名访问根路径常返回 **403**，说明端口在监听。  

   Windows（PowerShell / CMD）：

   ```bash
   curl.exe -s -o NUL -w "%{http_code}\n" http://127.0.0.1:9000/
   ```

   Linux / macOS（端口与 **`.env`** 中 **`RUSTFS_PORT_9000`** 一致时）：

   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9000/
   ```

## 日常使用

### 备份与迁移

停止后复制 **`RUSTFS_DATA_DIR`** 指向的整个目录即可冷备份；换机器后复制到同一路径（或在新 **`.env`** 里改路径）再 **`docker compose up -d`**。

### 与客户端配置

S3 兼容客户端使用 **`http://127.0.0.1:<RUSTFS_PORT_9000>`**（或 **`http://localhost:...`**），**path-style** 一般需开启；密钥与 **`.env`** 中一致。

### 停止

```bash
docker compose down
```

`down` **不会**删除 **`RUSTFS_DATA_DIR`** 内对象；清空需手动删该目录（**不可恢复**）。

---

## 参考链接

- [RustFS 文档](https://docs.rustfs.com/)
- [RustFS Docker Hub](https://hub.docker.com/r/rustfs/rustfs)
