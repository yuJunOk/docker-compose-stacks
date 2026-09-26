#!/bin/sh
# svn-server 首启初始化脚本（POSIX sh，兼容 Alpine busybox ash）
# 仅在仓库首次创建时写入账号与权限；仓库已存在则跳过，保证重启幂等。
set -eu

# 仓库根目录与镜像上游保持一致：/var/opt/svn（garethflowers/svn-server）
SVN_ROOT=/var/opt/svn
REPO="${SVN_REPO:-repo}"
USERNAME="${SVN_USERNAME:-svnuser}"
PASSWORD="${SVN_PASSWORD:?请在容器环境变量中设置 SVN_PASSWORD}"
REPO_DIR="$SVN_ROOT/$REPO"

if [ ! -d "$REPO_DIR/conf" ]; then
    echo "[svn-entrypoint] 首次启动，创建仓库: $REPO"
    svnadmin create "$REPO_DIR"

    # 服务配置：禁止匿名、登录用户可写，使用同目录 passwd / authz
    cat > "$REPO_DIR/conf/svnserve.conf" <<EOF
[general]
anon-access = none
auth-access = write
password-db = passwd
authz-db = authz
realm = $REPO

[sasl]
EOF

    # 账号文件：svnserve 原生明文口令文件，请避免在密码中使用 # ; 与换行
    cat > "$REPO_DIR/conf/passwd" <<EOF
[users]
$USERNAME = $PASSWORD
EOF

    # 授权：管理员组对整个仓库可读写，其余账号默认无权限
    cat > "$REPO_DIR/conf/authz" <<EOF
[groups]
admins = $USERNAME

[$REPO:/]
@admins = rw
* =
EOF
else
    echo "[svn-entrypoint] 仓库已存在，跳过初始化: $REPO"
fi

exec /usr/bin/svnserve --daemon --foreground --root "$SVN_ROOT"
