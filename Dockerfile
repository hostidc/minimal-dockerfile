# ============================================
# Optimized Dockerfile for Jupyter/MyBinder Environment
# ============================================
FROM ubuntu:24.04

# 1. 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 2. 允许 pip 在 Ubuntu 24.04 中全局安装包 (绕过 PEP 668 限制)
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 3. 强制设置默认 Shell 和终端类型
ENV SHELL=/bin/bash
ENV TERM=xterm-256color

# 4. 以 root 身份安装所有系统级依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates git iproute2 procps net-tools dnsutils tree jq vim-tiny nano less unzip zip tar gzip \
    openssh-client openssh-server \
    traceroute telnet netcat-openbsd \
    file xxd \
    htop iotop strace lsof \
    python3 python3-pip python3-venv python3-dev \
    build-essential libssl-dev pkg-config \
    cmake gdb \
    sudo locales tzdata man-db software-properties-common \
    ffmpeg \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev libavfilter-dev \
    libasound2-dev libpulse-dev \
    maven \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 5. 安装 Jupyter 核心组件 + 资源监控插件 (防断开调试神器)
RUN pip3 install --no-cache-dir \
    notebook \
    jupyterlab \
    jupyter-resource-usage

# 6. 创建非 root 用户
ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER=${NB_USER}
ENV HOME=/home/${NB_USER}

RUN userdel -r ubuntu || true && \
    adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    --shell /bin/bash \
    ${NB_USER}

# 7. 安装 Node.js 和版本切换工具 'n' (无 root 权限版)
ENV N_PREFIX=${HOME}/.local
ENV PATH=${N_PREFIX}/bin:${PATH}
ENV NODE_VERSION=20.18.0

RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then NODE_ARCH="x64"; else NODE_ARCH=$ARCH; fi && \
    mkdir -p ${N_PREFIX} && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz -o /tmp/node.tar.xz && \
    tar -xJf /tmp/node.tar.xz -C ${N_PREFIX} --strip-components=1 && \
    rm /tmp/node.tar.xz && \
    npm install -g n && \
    npm cache clean --force && \
    chown -R ${NB_UID}:${NB_UID} ${HOME}/.local

# 8. 确保终端有颜色且 ll 命令可用
RUN echo "alias ll='ls -alF'" > /etc/profile.d/99-custom-aliases.sh && \
    echo "alias la='ls -A'" >> /etc/profile.d/99-custom-aliases.sh && \
    echo "alias l='ls -CF'" >> /etc/profile.d/99-custom-aliases.sh && \
    echo "force_color_prompt=yes" >> /etc/profile.d/99-custom-aliases.sh && \
    chmod +x /etc/profile.d/99-custom-aliases.sh

# 9. 【核心修复】移交 HOME 目录控制权
RUN chown -R ${NB_UID}:${NB_UID} ${HOME}

# 10. 切换工作目录和用户
WORKDIR ${HOME}
USER ${USER}

# 11. 优化启动命令：兼容 MyBinder 的环境变量注入，并禁用部分不必要的检查以加快启动
CMD ["sh", "-c", "jupyter lab --ip=0.0.0.0 --port=${PORT:-8888} --no-browser --ServerApp.token='' --ServerApp.allow_origin='*'"]
