# ============================================
# Minimal Dockerfile for Jupyter/MyBinder Environment
# ============================================
FROM ubuntu:24.04

# 1. 设置非交互模式，防止 apt 安装时弹出配置界面卡住构建
ENV DEBIAN_FRONTEND=noninteractive

# 2. 允许 pip 在 Ubuntu 24.04 中全局安装包 (绕过 PEP 668 限制)
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# 3. 以 root 身份安装所有系统级依赖 (必须在切换 USER 之前执行)
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

# 4. 升级 pip 并安装 Jupyter 核心组件
RUN pip3 install --no-cache-dir notebook jupyterlab

# 5. 创建非 root 用户并设置环境 (MyBinder 默认通常为 jovyan)
ARG NB_USER=jovyan
ARG NB_UID=1000

ENV USER=${NB_USER}
ENV HOME=/home/${NB_USER}

RUN userdel -r ubuntu || true && \
    adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER} && \
    usermod -aG sudo ${NB_USER}

# ============================================
# 【新增修复】确保终端有颜色且 ll 命令可用
# ============================================
RUN echo "alias ll='ls -alF'" >> /etc/bash.bashrc && \
    echo "alias la='ls -A'" >> /etc/bash.bashrc && \
    echo "alias l='ls -CF'" >> /etc/bash.bashrc && \
    echo "force_color_prompt=yes" >> /etc/bash.bashrc

# 设置终端环境变量以支持 256 色显示
ENV TERM=xterm-256color

# 6. 切换工作目录和用户
WORKDIR ${HOME}
USER ${USER}

# 7. 默认启动命令 (MyBinder 会自动覆盖此命令，但本地测试时需要)
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
