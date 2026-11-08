# ============================================
# Minimal Dockerfile for Jupyter/MyBinder Environment
# ============================================
FROM ubuntu:24.04

# 1. 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 2. 允许 pip 在 Ubuntu 24.04 中全局安装包 (绕过 PEP 668 限制)
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 3. 强制设置默认 Shell 和终端类型
ENV SHELL=/bin/bash
ENV TERM=xterm-256color

# 4. 以 root 身份安装所有系统级依赖 (包含 maven)
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
    maven \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 5. 安装 Jupyter 核心组件
RUN pip3 install --no-cache-dir notebook jupyterlab

# 6. 创建非 root 用户 (提前创建，以便后续将 Node 安装到用户目录)
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

# 7. ============================================
#    安装 Node.js 和版本切换工具 'n' (无 root 权限版)
# ============================================
# 【核心技巧】设置 N_PREFIX，让 n 把 Node 安装到用户的 ~/.local 目录下，彻底告别 sudo！
ENV N_PREFIX=${HOME}/.local
ENV PATH=${N_PREFIX}/bin:${PATH}

ENV NODE_VERSION=20.18.0

RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then NODE_ARCH="x64"; else NODE_ARCH=$ARCH; fi && \
    mkdir -p ${N_PREFIX} && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz -o /tmp/node.tar.xz && \
    tar -xJf /tmp/node.tar.xz -C ${N_PREFIX} --strip-components=1 && \
    rm /tmp/node.tar.xz && \
    # 安装 n 到用户的 ~/.local/bin 下
    npm install -g n && \
    # 确保 jovyan 用户完全拥有 .local 目录
    chown -R ${NB_UID}:${NB_UID} ${HOME}/.local

# 8. 确保终端有颜色且 ll 命令可用
RUN echo "alias ll='ls -alF'" > /etc/profile.d/99-custom-aliases.sh && \
    echo "alias la='ls -A'" >> /etc/profile.d/99-custom-aliases.sh && \
    echo "alias l='ls -CF'" >> /etc/profile.d/99-custom-aliases.sh && \
    echo "force_color_prompt=yes" >> /etc/profile.d/99-custom-aliases.sh && \
    chmod +x /etc/profile.d/99-custom-aliases.sh

# 9. ============================================
#    【核心修复】在切换用户前，将 HOME 目录的完全控制权移交给普通用户
#    这会清除 root 在第 7 步运行 npm 时留下的 ~/.npm 等目录的 root 权限
# ============================================
RUN chown -R ${NB_UID}:${NB_UID} ${HOME}

# 10. 切换工作目录和用户
WORKDIR ${HOME}
USER ${USER}

# 11. 默认启动命令 (因为已经是 jovyan 用户，去掉了 --allow-root)
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser"]
