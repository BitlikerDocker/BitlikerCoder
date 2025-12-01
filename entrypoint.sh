#!/bin/bash
set -e

# 更改 coder userid 和 groupid
groupmod -o -g "${PGID}" coder
usermod -o -u "${PUID}" coder

# 更改文件权限
chown -R coder:coder "${HOME}" 

echo "coder:${PASSWORD:-coder}" | chpasswd

# 启动 code-server
if [ -n "$PASSWORD" ]; then
    exec gosu coder:coder dumb-init /usr/bin/code-server --auth password --host 0.0.0.0 --port 8080 --user-data-dir ${USER_DATA} --extensions-dir ${USER_EXTENSIONS}
else
    exec gosu coder:coder dumb-init /usr/bin/code-server --auth none --host 0.0.0.0 --port 8080 --user-data-dir ${USER_DATA} --extensions-dir ${USER_EXTENSIONS}
fi