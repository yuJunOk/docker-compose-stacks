# SVN 服务端（单机 Docker Compose）

本目录提供一份单机 **Apache Subversion** 服务端，基于 [`garethflowers/svn-server`](https://hub.docker.com/r/garethflowers/svn-server)（内置 **svnserve**，使用原生 **`svn://`** 协议）。**首次启动自动创建仓库与管理员账号**，仓库数据持久化到命名卷，默认仅本机可连。

---

## 概览

| 项目 | 说明 |
|------|------|
| 镜像 | **`SVN_IMAGE`**（默认 **`garethflowers/svn-server:1.8.1`**，内含 Subversion 1.14.5 / Alpine 3.23） |
| 端口 | 宿主机 **`SVN_BIND`**:**`SVN_PORT`**（默认 **127.0.0.1:3690**）→ 容器 **3690** |
| 数据 / 卷 | 命名卷 **`svn-data`** → 容器内 **`/var/opt/svn`**（镜像声明的 VOLUME，多仓库同卷存放） |
| 认证 | svnserve 原生口令文件 **`conf/passwd`**；首启由 **`docker-entrypoint.sh`** 按 **`.env`** 自动写入管理员账号，**`anon-access = none`** 禁止匿名 |
| 授权 | 仓库 **`conf/authz`**：管理员组对整库 **`rw`**，其余账号默认无权限 |
| 健康检查 | Compose **`healthcheck`**（`netstat -ln` 探测 3690，与镜像上游一致）；**`docker compose ps`** 为 **`healthy`** 即就绪 |
| 可视化 / 管理 | **无** Web 界面；使用 **TortoiseSVN**、**IntelliJ IDEA / Android Studio**、命令行 **`svn`** 等客户端连接 |

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

编辑 **`.env`**，**必须修改**：

- **`SVN_PASSWORD`**：管理员密码（会明文写入仓库的 `conf/passwd`，避免使用 `#`、`;`、换行；勿提交 `.env`）。

按需修改：

- **`SVN_REPO`**：首启自动创建的仓库名（仅字母、数字、`-`、`_`），默认 **`repo`**；
- **`SVN_USERNAME`**：管理员用户名，默认 **`svnuser`**；
- **`SVN_BIND` / `SVN_PORT`**：绑定地址与宿主机端口。

**注意**：`SVN_REPO`、`SVN_USERNAME`、`SVN_PASSWORD` 仅在**仓库首次创建**时由初始化脚本写入；仓库已存在后修改 `.env` 不会自动改动仓内账号或密码，需按下文「日常使用」手动维护（与卷初始化类镜像行为一致）。

### 2. 启动

```bash
docker compose up -d
```

> **Windows 提示**：容器通过绑定挂载执行 **`docker-entrypoint.sh`**，该文件必须为 **LF** 行尾（仓库已配 **`.gitattributes`** 强制）。若启动日志出现 `not found` / 语法异常，请检查该文件是否被编辑器改成 CRLF。

### 3. 验证

```bash
docker compose ps
```

**`svn`** 状态为 **`healthy`** 即健康检查通过（首启一般只需数秒）；同时 **`docker compose logs svn`** 应能看到「首次启动，创建仓库: repo」。

容器内做一次 **导入 → 列表** 闭环验证（无需宿主机安装 `svn` 客户端；bash 与 PowerShell 均可直接执行）：

```bash
docker compose exec svn sh -c 'mkdir -p /tmp/svn-init/{trunk,tags,branches} && svn import -m "初始化标准目录" /tmp/svn-init "svn://127.0.0.1/$SVN_REPO" --username "$SVN_USERNAME" --password "$SVN_PASSWORD" --non-interactive'
```

```bash
docker compose exec svn sh -c 'svn list "svn://127.0.0.1/$SVN_REPO" --username "$SVN_USERNAME" --password "$SVN_PASSWORD" --non-interactive'
```

预期输出：

```text
branches/
tags/
trunk/
```

查看仓库信息（URL、UUID、版本号）：

```bash
docker compose exec svn sh -c 'svn info "svn://127.0.0.1/$SVN_REPO" --username "$SVN_USERNAME" --password "$SVN_PASSWORD" --non-interactive'
```

**（可选）宿主机已安装 SVN 客户端时**，检出地址为（账号密码以 `.env` 为准，勿粘贴真实密码到文档或聊天记录）：

```text
svn://127.0.0.1:3690/repo
```

将 `repo` 换成 **`SVN_REPO`** 的值；TortoiseSVN / IDEA 在「版本控制 URL」处填同一地址即可。

---

## 日常使用

### 局域网访问

默认端口绑定 **`127.0.0.1`**，只能本机连接。需要团队内网访问时，把 **`.env`** 中改为：

```text
SVN_BIND=0.0.0.0
```

随后 `docker compose up -d` 生效。客户端连接地址改为 **`svn://<宿主机IP>:3690/<仓库名>`**，并务必在防火墙限制来源 IP、使用强密码。

### 新增仓库

容器工作目录即仓库根目录，`svnadmin create` 可直接用仓库名。例如新建仓库 **`demo`**：

```bash
docker compose exec svn svnadmin create demo
```

新仓库默认允许匿名读、且无账号。可参考 **`docker-entrypoint.sh`** 中的写法，覆盖 **`/var/opt/svn/demo/conf/`** 下的 **`svnserve.conf`**、**`passwd`**、**`authz`**（`[$REPO:/]` 处替换为 `[demo:/]`），无需重启容器，下次连接即生效。

### 修改密码 / 增删账号

svnserve 每次连接都会重读仓库配置文件，**改完无需重启**：

```bash
docker compose exec svn vi /var/opt/svn/repo/conf/passwd
docker compose exec svn vi /var/opt/svn/repo/conf/authz
```

- **`passwd`** 的 `[users]` 段按 `用户名 = 密码` 一行一个账号；
- **`authz`** 中配置组与仓库路径权限（如 `[repo:/trunk]`、`@开发组 = rw`）。

### 备份与恢复

推荐 **`svnadmin hotcopy`** 在线热备（仓库可正常使用），备份在容器内完成后再用 `docker cp` 取出，跨平台一致：

```bash
docker compose exec svn svnadmin hotcopy /var/opt/svn/repo /tmp/repo-hotcopy
docker cp svn-server:/tmp/repo-hotcopy ./repo-hotcopy
```

恢复时停服，将备份目录拷回命名卷对应路径，或对新空仓库执行 `svnadmin load` 导入 dump：

```bash
docker compose stop svn
docker cp ./repo-hotcopy svn-server:/var/opt/svn/repo
docker compose start svn
```

### 停止与删卷（清空数据）

```bash
docker compose down
docker volume rm svn-data
```

第二行会删除**全部仓库数据**，请确认已有备份后再执行。

### 安全说明

- **`svn://` 协议不加密传输内容**：认证默认使用 CRAM-MD5 挑战，口令本身不明文传输，但代码数据在网络上明文可见；公网场景请走 **`svn+ssh`**、VPN / 专线，或改用 Apache **`mod_dav_svn`** 的 HTTPS 方案（本示例不包含）。
- 已默认 **`anon-access = none`** 禁止任何匿名访问。
- `.env` 与卷内 `conf/passwd` 均含明文口令，请注意宿主机制权限与备份介质安全。

---

## 参考

- [Docker Hub：garethflowers/svn-server](https://hub.docker.com/r/garethflowers/svn-server)
- [GitHub：garethflowers/docker-svn-server](https://github.com/garethflowers/docker-svn-server)
- [Version Control with Subversion（SVN Book）](https://svnbook.red-bean.com/)（[svnserve 服务端配置](https://svnbook.red-bean.com/en/1.7/svn.serverconfig.svnserve.html)）
