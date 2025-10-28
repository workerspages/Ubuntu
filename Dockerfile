# 步骤 1: 使用 Ubuntu 22.04 作为基础镜像
FROM ubuntu:22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 更换 APT 软件源为 Amazon AWS 在美国的镜像
RUN sed -i 's@http://archive.ubuntu.com@http://us-east-1.ec2.archive.ubuntu.com@g' /etc/apt/sources.list && \
    sed -i 's@http://security.ubuntu.com@http://us-east-1.ec2.archive.ubuntu.com@g' /etc/apt/sources.list

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 步骤 2: 安装系统依赖 (!!! 关键修复 1: 内部增加重试逻辑 !!!)
# 这个脚本块会尝试最多3次，每次间隔15秒，以抵抗网络抖动
RUN for i in 1 2 3; do \
      apt-get update && \
      apt-get install -y --no-install-recommends \
        cron git sudo vim lsof \
        wget unzip curl gnupg msmtp \
        python3 python3-pip ca-certificates \
        fonts-wqy-zenhei fonts-wqy-microhei \
        libglib2.0-0 libnss3 libgconf-2-4 libfontconfig1 && \
      break; \
    done || exit 1

# 步骤 3: 安装 Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# 步骤 4: 下载并安装 Uptime Kuma
RUN git clone https://github.com/louislam/uptime-kuma.git /app
WORKDIR /app
# npm install 也可能因网络问题失败，为它也加上重试
RUN for i in 1 2 3; do npm run setup && break || sleep 15; done || exit 1

# 步骤 5: 安装 Google Chrome 浏览器
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
# 为 Chrome 的安装也加上重试
RUN for i in 1 2 3; do \
      apt-get update && \
      apt-get install -y google-chrome-stable --no-install-recommends && \
      break; \
    done || exit 1

# (后续步骤保持不变)

# 步骤 6: 安装 ChromeDriver
RUN CHROME_VERSION=$(google-chrome --version | cut -d " " -f3 | cut -d "." -f1-3) && \
    DRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | python3 -c "import sys, json; print(next(v['version'] for v in reversed(json.load(sys.stdin)['versions']) if v['version'].startswith('$CHROME_VERSION')))") && \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-linux64.zip" -O chromedriver.zip && \
    unzip chromedriver.zip && \
    mv chromedriver-linux64/chromedriver /usr/bin/chromedriver && \
    chown root:root /usr/bin/chromedriver && \
    chmod +x /usr/bin/chromedriver && \
    rm chromedriver.zip && rm -rf chromedriver-linux64

# 步骤 7: 安装 cloudflared
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# 步骤 8: 使用 pip 安装 Python 库
RUN pip3 install \
    --no-cache-dir \
    --break-system-packages \
    requests \
    selenium \
    Pillow \
    python-telegram-bot

# 步骤 9: 复制您的自定义脚本和 cron 配置文件
COPY my_monitoring_script.py /app/my_monitoring_script.py
COPY crontab.txt /etc/cron.d/my-cron
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
