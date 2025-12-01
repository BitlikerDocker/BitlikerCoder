# code-server 镜像（基于 Debian + code-server）

本仓库包含一个用于构建远程开发容器的 Dockerfile：将 code-server 与常用开发工具打包为镜像，方便在容器中进行 Web IDE 开发。

核心功能

- code-server（Web IDE）
- Temurin JDK 21（用于 Java/Gradle 构建与运行）
- Gradle（可通过 build-arg 指定版本）
- Kotlin 编译器（kotlinc）
- rar / unrar 支持
- 已生成 zh_CN.UTF-8 本地化

常用环境变量（摘自 Dockerfile）

- PUID / PGID：容器内运行用户与组（默认 1000）
- TZ：时区（示例 Asia/Shanghai）
- LANG：语言环境（镜像已启用 zh_CN.UTF-8）
- USER_DATA / USER_EXTENSIONS / DEFAULT_WORKSPACE：持久化目录位置
- GRADLE_USER_HOME：Gradle 缓存目录（默认 /home/coder/.gradle）
- SHELL：默认 shell（/bin/bash）
- JAVA_HOME：JDK 路径（/usr/lib/jvm/temurin-21-jdk-amd64）

构建镜像（推荐启用 BuildKit / buildx）

临时启用 BuildKit 并构建（PowerShell）：

```powershell
$env:DOCKER_BUILDKIT=1
docker build -t bitliker/code-server:local .
```

使用 buildx 并持久化缓存（CI 环境推荐）

```powershell
docker buildx create --use --name mybuilder
docker buildx build --progress=plain --cache-to=type=local,dest=./.buildx-cache --cache-from=type=local,src=./.buildx-cache -t bitliker/code-server:local --load .
```

运行镜像（示例）

```powershell
docker run --rm -p 8080:8080 -e TZ=Asia/Shanghai -e PUID=1000 -e PGID=1000 -v $env:USERPROFILE\code-server-data:/home/coder/data -v $env:USERPROFILE\code-server-extensions:/home/coder/extensions bitliker/code-server:local
```

验证（容器内）

检查 Java：

```powershell
docker run --rm -it bitliker/code-server:local bash -lc "java -version && echo JAVA_HOME=$JAVA_HOME"
```

检查 Gradle：

```powershell
docker run --rm -it bitliker/code-server:local bash -lc "gradle -v && echo GRADLE_HOME=$GRADLE_HOME"
```

访问 code-server

在浏览器打开 `http://HOST:8080`，根据 entrypoint.sh 中的配置登录（或根据你在环境变量中配置的方式）。

优化建议

- 若运行时仅需执行 Java 程序，可仅复制 JRE 或将构建产物移除运行镜像以减小体积；
- 在 CI/多机场景中，应使用 buildx 缓存（`--cache-to/--cache-from`）以加速依赖层构建；
- 将 `USER_DATA`、`USER_EXTENSIONS`、`DEFAULT_WORKSPACE` 等目录挂载为卷用于持久化。


