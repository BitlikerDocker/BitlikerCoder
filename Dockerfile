FROM debian:stable-slim AS builder

############################start params########################################
# code-server 版本
ARG CODE_RELEASE
ARG KOTLIN_RELEASE
# gradle 版本
ARG GRADLE_VERSION="9.2.1"
# rar 版本
ARG RAR_VERSION="710"
############################end params############################################

# 安装linux 基础软件依赖
RUN apt-get update \
    && apt-get install -y \
    bash \
    sudo \
    curl \
    wget \
    jq  \
    unzip \
    ca-certificates \
    gnupg \
    apt-transport-https

RUN echo "安装其他内容" \
    # 安装code-server
    && if [ -z ${CODE_RELEASE+x} ]; then  \
    CODE_RELEASE=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | jq -r '.tag_name | gsub("v"; "")'); \
    fi \
    && wget -P /tmp/ "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" \
    && tar zxvf /tmp/code-server-${CODE_RELEASE}-linux-amd64.tar.gz -C /usr/local \
    && mv /usr/local/code-server-${CODE_RELEASE}-linux-amd64 /usr/local/bin/code-server \
    ## 安装kotlin
    && if [ -z ${KOTLIN_RELEASE+x} ]; then  \
    KOTLIN_RELEASE=$(curl -s https://api.github.com/repos/JetBrains/kotlin/releases/latest | jq -r '.tag_name | gsub("v"; "")'); \
    fi \
    && wget -P /tmp/ "https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_RELEASE}/kotlin-compiler-${KOTLIN_RELEASE}.zip" \
    && unzip /tmp/kotlin-compiler-${KOTLIN_RELEASE}.zip -d /usr/local/bin \
    # "安装 RAR" 
    && wget -P /tmp/  "http://www.rarlab.com/rar/rarlinux-x64-${RAR_VERSION}.tar.gz"  \
    && tar zxvf /tmp/rarlinux-x64-${RAR_VERSION}.tar.gz -C /usr/local/bin \
    # 安装 JDK21 (Temurin) 到 builder 阶段，仅用于构建步骤，减小最终镜像
    && wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium-archive-keyring.gpg \
    # 使用系统的 VERSION_CODENAME 来选择正确的 deb 目录 (避免使用不存在的 'stable' release)
    && . /etc/os-release \
    && echo "deb [signed-by=/usr/share/keyrings/adoptium-archive-keyring.gpg] https://packages.adoptium.net/artifactory/deb $VERSION_CODENAME main" > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y temurin-21-jdk \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    GRADLE_VER=${GRADLE_VERSION:-9.2.1}; \
    wget -P /tmp/ "https://services.gradle.org/distributions/gradle-${GRADLE_VER}-bin.zip"; \
    unzip /tmp/gradle-${GRADLE_VER}-bin.zip -d /opt; \
    ln -s /opt/gradle-${GRADLE_VER} /usr/local/gradle; \
    ln -s /usr/local/gradle/bin/gradle /usr/bin/gradle; \
    rm -f /tmp/gradle-${GRADLE_VER}-bin.zip

ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
ENV GRADLE_HOME=/usr/local/gradle


#**********************************************************************************#
############################start matadata########################################
ARG AUTHOR="bitliker"
ARG HOMEPAGE="https://github.com/BitlikerDocker/BitlikerCoder"
ARG DOCKER_HUB="https://hub.docker.com/r/bitliker/code-server"
LABEL org.opencontainers.image.created="2024-05-15T14:31:17+00:00"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source=${HOMEPAGE}
LABEL org.opencontainers.image.title="bitliker/code-server"
LABEL org.opencontainers.image.url=${DOCKER_HUB}
LABEL org.opencontainers.image.vendor=${AUTHOR}
LABEL org.opencontainers.image.description="基于 debian:bullseye-slim + code-server 镜像构建 code-server 环境"
############################end matadata########################################


FROM debian:stable-slim

ENV PUID=1000 \
    PGID=1000 \
    TZ=Asia/Shanghai \
    LANG=zh_CN.UTF-8 \
    # 基础目录
    BASE_DIR=/home 

ENV HOME=${BASE_DIR}/coder
ENV USER_DATA=${HOME}/data \
    USER_EXTENSIONS=${HOME}/extensions \
    DEFAULT_WORKSPACE=${BASE_DIR}/workspace \
    GRADLE_USER_HOME=${HOME}/.gradle

ENV SHELL=/bin/bash
ENV JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64
ENV GRADLE_HOME=/usr/local/gradle
ENV PATH=${JAVA_HOME}/bin:${GRADLE_HOME}/bin:${PATH}

# 创建用户组和用户
RUN groupadd -g ${PGID} coder \
    && useradd -u ${PUID} -g coder -m -s /bin/bash coder \
    && mkdir -p ${HOME} ${DEFAULT_WORKSPACE} \
    && chown -R coder:coder ${HOME} ${DEFAULT_WORKSPACE}


# 安装linux 基础软件依赖
RUN apt-get update \
    && apt-get install -y \
    bash \
    sudo \
    curl \
    wget \
    jq  \
    nano \
    locales \
    zsh \
    procps \
    dumb-init \
    git \
    cron \
    unzip \ 
    zip \
    p7zip-full \
    python3 \
    python3-pip \
    python3-venv \
    mkisofs \ 
    convmv \ 
    rsync \
    gosu \
    ffmpeg \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && usermod -aG sudo coder \
    # 生成并启用 zh_CN.UTF-8 本地化（确保 LANG=zh_CN.UTF-8 可用）
    && sed -i 's/^# *\(zh_CN.UTF-8 UTF-8\)/\1/' /etc/locale.gen || echo 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen \
    && locale-gen zh_CN.UTF-8 \
    && update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANG=C.UTF-8 LC_MESSAGES=POSIX || true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 复制 /usr/local/bin 目录
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/lib/jvm /usr/lib/jvm
COPY --from=builder /usr/local/gradle /usr/local/gradle
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN  chmod +x /usr/local/bin/entrypoint.sh \
    && ln -s /usr/local/bin/code-server/bin/code-server /usr/bin/code-server \
    && ln -s /usr/local/bin/kotlinc/bin/kotlin /usr/bin/kotlin \
    && ln -s /usr/local/bin/kotlinc/bin/kotlinc /usr/bin/kotlinc \
    && ln -s /usr/local/bin/rar/rar /usr/bin/rar \
    && ln -s /usr/local/bin/rar/unrar /usr/bin/unrar \
    && if [ -x "${JAVA_HOME}/bin/java" ]; then ln -sf ${JAVA_HOME}/bin/java /usr/bin/java; fi \
    && if [ -x "${JAVA_HOME}/bin/javac" ]; then ln -sf ${JAVA_HOME}/bin/javac /usr/bin/javac; fi \
    && if [ -x "${GRADLE_HOME}/bin/gradle" ]; then ln -sf ${GRADLE_HOME}/bin/gradle /usr/bin/gradle; fi

# code-server 默认设置：让终端默认使用 bash（兼容旧版/新版 code-server）
RUN mkdir -p ${HOME}/.local/share/code-server/User \
    && cat > ${HOME}/.local/share/code-server/User/settings.json <<'JSON'
{
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.profiles.linux": {
        "bash": {
            "path": "/bin/bash",
            "args": []
        }
    }
}
JSON

RUN chown -R coder:coder ${HOME}/.local/share/code-server

EXPOSE 8080
WORKDIR ${HOME}


ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]