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

# 4. 以 root 身份安装所有系统级依赖 (必须在切换 USER 之前执行)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 核心基础工具
    curl wget ca-certificates git iproute2 procps net-tools dnsutils tree jq vim-tiny nano less unzip zip tar gzip \
    # SSH 相关工具 
    openssh-client openssh-server \
    # 网络调试工具
    traceroute telnet netcat-openbsd \
    # 文件处理工具
    file xxd \
    # 系统监控工具
    htop iotop strace lsof \
    # Python 编译与虚拟环境支持
    python3 python3-pip python3-venv python3-dev \
    # NVM/Node.js 原生模块编译依赖
    build-essential libssl-dev pkg-config \
    # 其他实用工具
    sudo locales tzdata man-db software-properties-common \
    # ============================================
    # 多媒体与 AI 多模态支持
    # ============================================
    ffmpeg \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev libavfilter-dev \
    libasound2-dev libpulse-dev \
    # 清理 apt 缓存，减小镜像体积
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 5. 直接安装 Jupyter 核心组件 (已移除 --upgrade pip 以避免 Debian 打包冲突)
RUN pip3 install --no-cache-dir notebook jupyterlab


# 6. ============================================
#    安装 NVM (Node Version Manager) 和 Node.js
# ============================================
ENV NVM_DIR=/usr/local/nvm
# 下载并安装 NVM 脚本
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# 指定要安装的 Node.js LTS 版本 (例如 20.18.0)
ENV NODE_VERSION 20.18.0
# 通过 bash 加载 nvm 并安装指定版本的 Node.js
RUN /bin/bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm use --delete-prefix v$NODE_VERSION --silent"

# 将 Node.js 和 npm 加入全局 PATH，确保任何用户都能直接使用 node 和 npm 命令
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH


# 7. 创建非 root 用户并设置环境 (显式指定 /bin/bash 为默认 shell)
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

# ============================================
# 【终极修复】确保终端有颜色且 ll 命令可用
# 使用 /etc/profile.d/ 是 Linux 管理全局 alias 的最佳实践
# ============================================
RUN echo "alias ll='ls -alF'" > /etc/profile.d/99-custom-aliases.sh && \
    echo "alias la='ls -A'" >> /etc/profile.d/99-custom-aliases.sh && \
    echo "alias l='ls -CF'" >> /etc/profile.d/99-custom-aliases.sh && \
    echo "force_color_prompt=yes" >> /etc/profile.d/99-custom-aliases.sh && \
    chmod +x /etc/profile.d/99-custom-aliases.sh

# 8. 切换工作目录和用户
WORKDIR ${HOME}
USER ${USER}

# 9. 默认启动命令 (MyBinder 会自动覆盖此命令，但本地测试时需要)
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
