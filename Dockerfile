# ============================================
# Minimal Dockerfile for Jupyter/MyBinder Environment
# ============================================
FROM ubuntu:24.04

# 1. 设置非交互模式，防止 apt 安装时弹出配置界面卡住构建
ENV DEBIAN_FRONTEND=noninteractive

# 2. 允许 pip 在 Ubuntu 24.04 中全局安装包 (绕过 PEP 668 限制)
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 3. 强制设置默认 Shell 和终端类型，确保 Jupyter Terminal 使用 bash 并支持彩色
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
    sudo locales tzdata man-db software-properties-common \
    ffmpeg \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev libavfilter-dev \
    libasound2-dev libpulse-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 5. 直接安装 Jupyter 核心组件
RUN pip3 install --no-cache-dir notebook jupyterlab

# 6. ============================================
#    安装 NVM 和 Node.js (支持后续版本切换)
# ============================================
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=20.18.0

# 【关键修复 1】先创建目录，防止 nvm 安装脚本因目录不存在而报错退出
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# 【关键修复 2】加载 nvm，安装指定版本并设为默认版本
RUN /bin/bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm alias default $NODE_VERSION"

# 将当前安装的 Node.js 版本加入全局 PATH，确保开箱即用
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# 7. ============================================
#    创建非 root 用户并设置环境
# ============================================
ARG NB_USER=jovyan
ARG NB_UID=1000

ENV USER=${NB_USER}
ENV HOME=/home/${NB_USER}

RUN userdel -r ubuntu || true && \
    adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    --shell /bin/bash \
    ${NB_USER} && \
    usermod -aG sudo ${NB_USER}

# 【关键修复 3】将 nvm 目录的所有权移交给非 root 用户！
# 如果不执行这一步，jovyan 用户将无法使用 nvm 命令切换版本
RUN chown -R ${NB_UID}:${NB_UID} $NVM_DIR

# 8. 确保终端有颜色且 ll 命令可用
RUN echo "alias ll='ls -alF'" > /etc/profile.d/99-custom-aliases.sh && \
    echo "alias la='ls -A'" >> /etc/profile.d/99-custom-aliases.sh && \
    echo "alias l='ls -CF'" >> /etc/profile.d/99-custom-aliases.sh && \
    echo "force_color_prompt=yes" >> /etc/profile.d/99-custom-aliases.sh && \
    chmod +x /etc/profile.d/99-custom-aliases.sh

# 9. 切换工作目录和用户
WORKDIR ${HOME}
USER ${USER}

# 10. 默认启动命令
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
