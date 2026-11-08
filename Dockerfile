# ============================================
# Minimal Dockerfile for Jupyter/MyBinder Environment
# Base: ubuntu/python (注意：原链接为 3.14-26.04_stable，请确认是否为 24.04 的笔误)
# ============================================
FROM ubuntu/python:3.12-24.04_stable

# 1. 设置非交互模式，防止 apt 安装时弹出配置界面卡住构建
ENV DEBIAN_FRONTEND=noninteractive

# 2. 以 root 身份安装所有系统级依赖 (必须在切换 USER 之前执行)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 核心基础工具
    curl wget ca-certificates git iproute2 procps net-tools dnsutils tree jq vim-tiny nano less unzip zip tar gzip \
    # SSH 相关工具 (如无需 SSH 登录容器，可移除 openssh-server)
    openssh-client openssh-server \
    # 网络调试工具
    traceroute telnet netcat-openbsd \
    # 文件处理工具
    file xxd \
    # 系统监控工具 (注：在部分受限容器环境中 strace/iotop 可能需要特权)
    htop iotop strace lsof \
    # Python 编译与虚拟环境支持
    python3 python3-pip python3-venv python3-dev \
    # NVM/Node.js 原生模块编译依赖
    build-essential libssl-dev pkg-config \
    # 其他实用工具
    sudo locales tzdata man-db software-properties-common \
    # ============================================
    # 多媒体与 AI 多模态支持 (重点增加部分)
    # ============================================
    ffmpeg \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev libavfilter-dev \
    libasound2-dev libpulse-dev \
    # 清理 apt 缓存，减小镜像体积
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 3. 升级 pip 并安装 Jupyter 核心组件
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir notebook jupyterlab

# 4. 创建非 root 用户并设置环境 (MyBinder 默认通常为 jovyan)
ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER} && \
    # 赋予该用户使用 sudo 的权限 (如果基础镜像支持)
    usermod -aG sudo ${NB_USER}

# 5. 切换工作目录和用户
WORKDIR ${HOME}
USER ${USER}
