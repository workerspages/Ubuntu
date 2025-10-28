# 步骤 1: 使用 Ubuntu 22.04 作为基础镜像
FROM ubuntu:22.04

# 设置环境变量，防止安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区为 Asia/Shanghai
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 步骤 2: 安装所有系统依赖和 Git
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # 新增 cron 定时任务服务
    cron \
    # 新增 Git，用于克隆仓库
    git \
    # 调试工具
    sudo vim lsof \
    # 系统工具
    wget unzip curl gnupg msmtp \
    # Python 环境
    python3 python3-pip \
    # Node.js 安装依赖
    ca-certificates \
    # 中文字体和 Chrome 依赖
    fonts-wqy-zenhei fonts-wqy-microhei \
    libglib2.0-0 libnss3 libgconf-2-4 libfontconfig1

# 步骤 3: 安装 Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# 步骤 4: 下载并安装 Uptime Kuma
RUN git clone https://github.com/louislam/uptime-kuma.git /app
WORKDIR /app
RUN npm run setup

# 步骤 5: 安装 Google Chrome 浏览器
# ... (此部分及后续 Chrome, ChromeDriver, cloudflared 的安装保持不变)
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable --no-install-recommends

RUN CHROME_VERSION=$(google-chrome --version | cut -d " " -f3 | cut -d "." -f1-3) && \
    DRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | python3 -c "import sys, json; print(next(v['version'] for v in reversed(json.load(sys.stdin)['versions']) if v['version'].startswith('$CHROME_VERSION')))") && \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-linux64.zip" -O chromedriver.zip && \
    unzip chromedriver.zip && \
    mv chromedriver-linux64/chromedriver /usr/bin/chromedriver && \
    chown root:root /usr/bin/chromedriver && \
    chmod +x /usr/bin/chromedriver && \
    rm chromedriver.zip && rm -rf chromedriver-linux64

RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# 步骤 8: 使用 pip 安装 Python 库 (!!! 已更新 !!!)
RUN pip3 install \
    --no-cache-dir \
    --break-system-packages \
    requests \
    selenium \
    Pillow \
    python-telegram-bot

# 步骤 9: 复制您的自定义脚本和 cron 配置文件
# 将您的 Python 脚本复制到 /app 目录下
COPY my_monitoring_script.py /app/my_monitoring_script.py
# 将 cron 配置文件复制到指定位置
COPY crontab.txt /etc/cron.d/my-cron
# 赋予 cron 配置文件正确的权限
RUN chmod 0644 /etc/cron.d/my-cron

# 步骤 10: 创建非 root 用户并授权
RUN useradd -m -s /bin/bash node && \
    chown -R node:node /app

# 步骤 11: 清理工作
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 复制启动脚本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 步骤 12: 切换到新创建的非 root 用户
USER node

# 设置最终的启动命令
CMD ["/start.sh"]
